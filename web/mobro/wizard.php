<!--
Modbros Monitoring Service (MoBro) - Raspberry Pi image
Copyright (C) 2020 ModBros
Contact: mod-bros.com

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>MoBro Setup</title>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>

  <link rel="shortcut icon" href="../resources/favicon.ico" type="image/x-icon"/>

  <link href="../vendor/bootstrap.min.css" rel="stylesheet"/>
  <link href="../vendor/bootstrap-select.min.css" rel="stylesheet"/>
  <link href="../vendor/fontawesome-free-5.13.0-web/css/all.min.css" rel="stylesheet"/>

  <style>

    .form-label {
      font-weight: bold;
    }

    .confirmation-header {
      font-weight: bold;
      margin-bottom: 0.5em;
    }

    .confirmation-title {
      color: dimgrey;
    }

    .multisteps-form__progress {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(0, 1fr));
    }

    .multisteps-form__progress-btn {
      position: relative;
      padding-top: 20px;
      color: rgba(108, 117, 125, 0.7);
      text-indent: -9999px;
      border: none;
      background-color: transparent;
      outline: none !important;
      cursor: pointer;
    }

    @media (min-width: 500px) {
      .multisteps-form__progress-btn {
        text-indent: 0;
      }
    }

    .multisteps-form__progress-btn:before {
      position: absolute;
      top: 0;
      left: 50%;
      display: block;
      width: 13px;
      height: 13px;
      content: '';
      -webkit-transform: translateX(-50%);
      transform: translateX(-50%);
      border: 2px solid currentColor;
      border-radius: 50%;
      background-color: #fff;
      box-sizing: border-box;
      z-index: 3;
    }

    .multisteps-form__progress-btn:after {
      position: absolute;
      top: 5px;
      left: calc(-50% - 13px / 2);
      display: block;
      width: 100%;
      height: 2px;
      content: '';
      background-color: currentColor;
      z-index: 1;
    }

    .multisteps-form__progress-btn:first-child:after {
      display: none;
    }

    .multisteps-form__progress-btn.js-active {
      color: #f30;
    }

    .multisteps-form__progress-btn.js-active:before {
      -webkit-transform: translateX(-50%) scale(1.2);
      transform: translateX(-50%) scale(1.2);
      background-color: currentColor;
    }

    .multisteps-form__form {
      position: relative;
    }

    .multisteps-form__panel {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 0;
      opacity: 0;
      visibility: hidden;
    }

    .multisteps-form__panel.js-active {
      height: auto;
      opacity: 1;
      visibility: visible;
    }

    .btn-primary,
    .btn-primary:active,
    .btn-primary:visited {
      color: white;
      background-color: #f30;
      border-color: #f30;
    }

    .btn-primary:hover {
      background-color: #e13300;
      border-color: #e13300;
      color: white;
    }

    .btn-outline-primary,
    .btn-outline-primary:active,
    .btn-outline-primary:disabled,
    .btn-outline-primary:visited {
      color: #f30;
      background-color: white;
      border-color: #f30;
    }

    .btn-outline-primary:hover {
      background-color: #f30;
      border-color: #f30;
      color: white;
    }

    .bootstrap-select .btn {
      border: 1px solid #ced4da;
    }

    .bootstrap-select .dropdown-item.active,
    .bootstrap-select .dropdown-item:active {
      background-color: #f30;
    }
  </style>

  <script src="../vendor/jquery-3.3.1.slim.min.js"></script>
  <script src="../vendor/bootstrap.bundle.min.js"></script>
  <script src="../vendor/bootstrap-select.min.js"></script>

</head>

<body>

<?php

include '../constants.php';
include '../util.php';

$eth = shell_exec('grep up /sys/class/net/*/operstate | grep eth0');
$ethConnected = isset($eth) && trim($eth) !== '';

$usb = shell_exec('grep up /sys/class/net/*/operstate | grep usb0');
$ethConnected = isset($usb) && trim($usb) !== '';

$ssid = shell_exec('iwgetid wlan0 -r');
$wlanConnected = isset($ssid) && trim($ssid) !== '';

$connected = $ethConnected || $wlanConnected;

$props = parseProperties(Constants::FILE_MOBRO_CONFIG);
// localization
$localization_country = getOrDefault($props['localization_country'], 'AT');
$localization_timezone = getOrDefault($props['localization_timezone'], 'UTC');

// discovery
$discovery_mode = getOrDefault($props['discovery_mode'], 'auto');
$discovery_key = getOrDefault($props['discovery_key'], 'mobro');
$discovery_ip = getOrDefault($props['discovery_ip'], '');

// network
$network_mode = $ethConnected ? 'eth' : 'wifi';
$network_ssid = getOrDefault($props['network_ssid'], '');
$network_pw = getOrDefault($props['network_pw'], '');
$network_wpa = getOrDefault($props['network_wpa'], '');
$network_hidden = getOrDefault($props['network_hidden'], '0');

// display
$display_driver = getOrDefault($props['display_driver'], 'hdmi');
$display_rotation = getOrDefault($props['display_rotation'], '0');
$display_screensaver = getOrDefault($props['display_screensaver'], 'disabled');
$display_delay = getOrDefault($props['display_delay'], '5');

$ssids = array();
$file = fopen(Constants::FILE_SSID, "r");
while ($file && !feof($file)) {
    $item = fgets($file);
    if (!empty(trim($item))) {
        $ssids[] = $item;
    }
}
closeFile($file);
$ssids = array_unique($ssids);

?>

<div class="container">
  <div class="multisteps-form mt-5">

    <div class="row">
      <div class="col-12 col-lg-8 ml-auto mr-auto mb-3">
        <div class="multisteps-form__progress">
          <button class="multisteps-form__progress-btn js-active font-weight-bold" type="button" title="Localization">
            <span><i class="fas fa-globe-europe"></i></span>
          </button>
          <button class="multisteps-form__progress-btn" type="button" title="Network">
            <span><i class="fas fa-network-wired"></i></span> / <span><i class="fas fa-wifi"></i></span>
          </button>
          <button class="multisteps-form__progress-btn" type="button" title="PC connection">
            <span><i class="fas fa-laptop-house"></i></span>
          </button>
          <button class="multisteps-form__progress-btn" type="button" title="Screen">
            <span><i class="fas fa-desktop"></i></span>
          </button>
          <button class="multisteps-form__progress-btn" type="button" title="Summary">
            <span><i class="fas fa-check-double"></i></span>
          </button>
        </div>
      </div>
    </div>

    <div class="row">
      <div class="col-12 col-lg-8 m-auto">
        <form id="configForm" class="multisteps-form__form" action="save.php" method="POST">

          <!-- LOCALIZATION SETUP -->
          <div class="multisteps-form__panel shadow p-4 rounded bg-white js-active">
            <h3 class="multisteps-form__title text-center">Localization</h3>
            <div class="multisteps-form__content">

              <div class="form-row mt-2">
                <div class="col">
                  <label class="form-check-label form-label" for="countryInput">
                    Country
                  </label>
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text">
                        <i class="fas fa-globe-europe"></i>
                      </span>
                    </div>
                    <select id="countryInput" name="localization_country" class="form-control selectpicker" data-live-search="true"
                            aria-describedby="countryInputHelp">
                        <?php
                        if (($handle = fopen("../resources/country_codes.csv", "r")) !== FALSE) {
                            while (($data = fgetcsv($handle, 1000, ",")) !== FALSE) {
                                $selected = $data[1] == $localization_country ? 'selected="selected"' : '';
                                $flag = "../resources/flags/" . (file_exists("../resources/flags/" . $data[1] . ".png") ? $data[1] : '_unknown') . ".png";
                                echo '<option data-content="<img src=\'' . $flag . '\' height=\'24px\' class=\'mr-2\'>' . $data[0]
                                    . '" value="' . $data[1] . '" ' . $selected . '>' . $data[0] . '</option>';
                            }
                            fclose($handle);
                        }
                        ?>
                    </select>
                  </div>
                  <small id="countryInputHelp" class="form-text text-muted">
                    The country in which the device is being used. <br>
                    This is needed so the 5G wireless networking can choose the correct frequency bands.
                  </small>
                </div>
              </div>

              <div class="form-row mt-2">
                <div class="col">
                  <label class="form-check-label form-label" for="timeZoneInput">
                    Timezone
                  </label>
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text">
                        <i class="fas fa-clock"></i>
                      </span>
                    </div>
                    <select id="timeZoneInput" name="localization_timezone" class="form-control selectpicker" data-live-search="true"
                            aria-describedby="timeZoneInputHelp">
                      <option value="UTC">UTC</option>
                        <?php
                        foreach (getGroupedTimeZones() as $group => $data) {
                            echo '<optgroup label="' . $group . '">';
                            foreach ($data as $key => $value) {
                                $selected = $localization_timezone == $key ? 'selected="selected"' : '';
                                echo '<option value="' . $key . '" ' . $selected . '>' . $value . '</option>';
                            }
                            echo '</optgroup>';
                        }
                        ?>
                    </select>
                  </div>
                  <small id="timeZoneInputHelp" class="form-text text-muted">
                    The timezone in which the device is being used. <br>
                    Needed so the correct time and date can be displayed (e.g. screensaver, ...)
                  </small>
                </div>
              </div>

              <div class="button-row d-flex mt-4">
                <a href="index.php" class="btn btn-danger" role="button" title="Cancel">
                  <span><i class="fas fa-times"></i></span> Cancel
                </a>
                <button class="btn btn-primary ml-auto js-btn-next" type="button" title="Next">
                  Next <span><i class="fas fa-chevron-circle-right"></i></span>
                </button>
              </div>
            </div>
          </div>

          <!-- NETWORK SETUP -->
          <div class="multisteps-form__panel shadow p-4 rounded bg-white">
            <h3 class="multisteps-form__title text-center">Network setup</h3>
            <div class="multisteps-form__content">
              <div class="form-row mt-4">
                <div class="font-weight-bold ml-2 mr-3">Mode:</div>
                <div>
                    <?php
                    if ($network_mode == 'eth') {
                        echo '<span><i class="fas fa-network-wired"></i></span> Ethernet';
                    } else {
                        echo '<span><i class="fas fa-wifi"></i></span> Wireless';
                    }
                    ?>
                </div>
                <input type="hidden" id="networkModeInput" name="network_mode" value="<?php echo $network_mode ?>">
              </div>
              <div class="form-row mt-4">
                <div class="col">
                  <label class="form-check-label form-label" for="ssidInput">
                    Wireless network name (SSID)
                  </label>
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text">
                        <i class="fas fa-wifi"></i>
                      </span>
                    </div>
                    <input list="ssids" class="form-control" name="network_ssid" id="ssidInput"
                           aria-describedby="ssidHelp" value="<?php echo $network_ssid ?>"
                        <?php if ($network_mode == 'eth') echo 'disabled' ?>
                    >
                    <datalist id="ssids">
                        <?php
                        foreach ($ssids as $ssid) {
                            echo '<option value="' . $ssid . '">' . $ssid . '</option>';
                        }
                        ?>
                    </datalist>
                  </div>
                  <small id="ssidHelp" class="form-text text-muted">
                    The network name (SSID) of the wireless network to connect to.
                  </small>
                </div>
              </div>

              <div class="form-row mt-2">
                <div class="col">
                  <label class="form-check-label form-label" for="passwordInput">
                    Wireless network password
                  </label>
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text">
                        <i class="fas fa-key"></i>
                      </span>
                    </div>
                    <input type="password" name="network_pw" class="form-control" id="passwordInput"
                           aria-describedby="pwHelp" value="<?php echo $network_pw ?>"
                        <?php if ($network_mode == 'eth') echo 'disabled' ?>
                    >
                  </div>
                  <small id="pwHelp" class="form-text text-muted">
                    The password needed to connect to the selected wireless network.
                  </small>
                </div>
              </div>

              <div class="form-row mt-1">
                <button class="btn btn-link ml-auto" type="button" data-toggle="collapse"
                        data-target="#networkAdvancedCollapse"
                        aria-expanded="false" aria-controls="networkAdvancedCollapse">
                  Advanced settings
                </button>
              </div>

              <div class="collapse" id="networkAdvancedCollapse">

                <div class="form-row mt-2">
                  <div class="col">
                    <label class="form-check-label form-label" for="wpaInput">
                      Security & Encryption standard
                    </label>
                    <div class="input-group">
                      <div class="input-group-prepend">
                      <span class="input-group-text">
                        <i class="fas fa-lock"></i>
                      </span>
                      </div>
                      <select id="wpaInput" name="network_wpa" class="form-control selectpicker" aria-describedby="wpaInputHelp"
                          <?php if ($network_mode == 'eth') echo 'disabled' ?>
                      >
                        <option value="" <?php if (empty($network_wpa)) echo 'selected="selected"' ?>>
                          Automatic
                        </option>
                        <option value="2a" <?php if ($network_wpa == '2a') echo 'selected="selected"' ?>>
                          WPA2-PSK (AES)
                        </option>
                        <option value="2t" <?php if ($network_wpa == '2t') echo 'selected="selected"' ?>>
                          WPA2-PSK (TKIP)
                        </option>
                        <option value="1t" <?php if ($network_wpa == '1t') echo 'selected="selected"' ?>>
                          WPA-PSK (TKIP)
                        </option>
                        <option value="n" <?php if ($network_wpa == 'n') echo 'selected="selected"' ?>>
                          None (Unsecured network)
                        </option>
                      </select>
                    </div>
                    <small id="wpaInputHelp" class="form-text text-muted">
                      The WPA version and encryption method to use. <br>
                      Only change this if 'Automatic' does not work and/or your router requires a specific WPA standard
                      or encryption method.
                    </small>
                  </div>
                </div>

                <div class="form-row mt-3">
                  <div class="col">
                    <div class="form-check">
                      <input type="checkbox" class="form-check-input" id="hiddenNetworkInput" name="network_hidden"
                             aria-describedby="hiddenNetworkHelp" <?php if ($network_hidden == '1') echo 'checked' ?>
                          <?php if ($network_mode == 'eth') echo 'disabled' ?>
                      >
                      <label class="form-check-label form-label" for="hiddenNetworkInput">
                        <span><i class="fas fa-ghost"></i></span> Hidden wireless network
                      </label>
                    </div>
                    <small id="hiddenNetworkHelp" class="form-text text-muted">
                      Check this if you configured your router to hide the wireless network name (SSID).
                    </small>
                  </div>
                </div>

              </div>

              <div class="button-row d-flex mt-4">
                <button class="btn btn-primary js-btn-prev" type="button" title="Prev">
                  <span><i class="fas fa-chevron-circle-left"></i></span> Prev
                </button>
                <button class="btn btn-primary ml-auto js-btn-next" type="button" title="Next">
                  Next <span><i class="fas fa-chevron-circle-right"></i></span>
                </button>
              </div>
            </div>
          </div>

          <!-- PC CONNECTION SETUP -->
          <div class="multisteps-form__panel shadow p-4 rounded bg-white">
            <h3 class="multisteps-form__title text-center">PC connection</h3>
            <div class="multisteps-form__content">
              <div class="form-row mt-4">
                <div class="col">
                  <div class="form-check">
                    <input class="form-check-input" type="radio" name="discovery_mode" id="discovery1" value="auto"
                        <?php if ($discovery_mode == 'auto') echo 'checked' ?>>
                    <label class="form-check-label" for="discovery1">
                      Automatic discovery using network name
                    </label>
                  </div>
                  <div class="form-check">
                    <input class="form-check-input" type="radio" name="discovery_mode" id="discovery2" value="manual"
                        <?php if ($discovery_mode == 'manual') echo 'checked' ?>>
                    <label class="form-check-label" for="discovery2">
                      Manual IP address configuration
                    </label>
                  </div>
                </div>
              </div>

              <div class="form-row mt-3">
                <div class="col">
                  <label class="form-check-label form-label" for="connectionKeyInput">
                    Network name
                  </label>
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text">
                        <i class="fas fa-search"></i>
                      </span>
                    </div>
                    <input class="multisteps-form__input form-control border-primary" id="connectionKeyInput"
                           type="text" name="discovery_key"
                           value="<?php echo $discovery_key ?>"
                           placeholder="mobro"
                           aria-describedby="connectionKeyHelp"
                    />
                  </div>
                  <small id="connectionKeyHelp" class="form-text text-muted">
                    The 'Network Name' as configured in the MoBro PC application. (default: mobro)
                  </small>
                </div>
              </div>

              <div class="form-row mt-2">
                <div class="col">
                  <label class="form-check-label form-label" for="staticIpInput">
                    Static IP address
                  </label>
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text">
                        <i class="fas fa-at"></i>
                      </span>
                    </div>
                    <input class="multisteps-form__input form-control" id="staticIpInput" type="text" name="discovery_ip"
                           aria-describedby="staticIpHelp" disabled
                           value="<?php echo $discovery_ip ?>"
                    />
                  </div>
                  <small id="staticIpHelp" class="form-text text-muted">
                    The static IP address of the PC within the network. (e.g.: 192.168.0.12)
                  </small>
                </div>
              </div>
              <div class="button-row d-flex mt-4">
                <button class="btn btn-primary js-btn-prev" type="button" title="Prev">
                  <span><i class="fas fa-chevron-circle-left"></i></span> Prev
                </button>
                <button class="btn btn-primary ml-auto js-btn-next" type="button" title="Next">
                  Next <span><i class="fas fa-chevron-circle-right"></i></span>
                </button>
              </div>
            </div>
          </div>

          <!-- SCREEN SETUP -->
          <div class="multisteps-form__panel shadow p-4 rounded bg-white">
            <h3 class="multisteps-form__title text-center">Screen setup</h3>
            <div class="multisteps-form__content">
              <div class="form-row mt-2">
                <div class="col">
                  <label class="form-check-label form-label" for="driverInput">
                    Display driver
                  </label>
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text">
                        <i class="fas fa-desktop"></i>
                      </span>
                    </div>
                    <select id="driverInput" name="display_driver" class="form-control selectpicker" data-live-search="true"
                            aria-describedby="driverInputHelp">
                        <?php
                        foreach (getOtherDriverOptions() as $key => $value) {
                            $selected = $display_driver == $key ? 'selected="selected"' : '';
                            echo '<option value="' . $key . '" ' . $selected . '>' . $value . '</option>';
                        }
                        echo '<optgroup label="GoodTFT">';
                        foreach (getGoodTFTDrivers() as $key => $value) {
                            $selected = $display_driver == $key ? 'selected="selected"' : '';
                            echo '<option value="' . $key . '" ' . $selected . '>' . $value . '</option>';
                        }
                        echo '</optgroup>';
                        echo '<optgroup label="WaveShare">';
                        foreach (getWaveshareDrivers() as $key => $value) {
                            $selected = $display_driver == $key ? 'selected="selected"' : '';
                            echo '<option value="' . $key . '" ' . $selected . '>' . $value . '</option>';
                        }
                        echo '</optgroup>';
                        ?>
                    </select>
                  </div>
                  <small id="driverInputHelp" class="form-text text-muted">
                    Check your display and select the corresponding driver from the list if required<br>
                  </small>
                </div>
              </div>

              <div class="form-row mt-2">
                <div class="col">
                  <label class="form-check-label form-label" for="rotationInput">
                    Rotation
                  </label>
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text">
                        <i class="fas fa-sync-alt"></i>
                      </span>
                    </div>
                    <select id="rotationInput" name="display_rotation" class="form-control selectpicker"
                            aria-describedby="rotationInputHelp">
                      <option value="0" <?php echo $display_rotation == '0' ? 'selected' : '' ?>>0°</option>
                      <option value="90" <?php echo $display_rotation == '90' ? 'selected' : '' ?>>90°</option>
                      <option value="180" <?php echo $display_rotation == '180' ? 'selected' : '' ?>>180°</option>
                      <option value="270" <?php echo $display_rotation == '270' ? 'selected' : '' ?>>270°</option>
                    </select>
                  </div>
                  <small id="rotationInputHelp" class="form-text text-muted">
                    Clockwise rotation of the display in degrees (0° = no rotation)<br>
                    Does not apply on manual driver installation!
                  </small>
                </div>
              </div>

              <hr>

              <div class="form-row mt-2">
                <div class="col">
                  <label class="form-check-label form-label" for="screensaverInput">
                    Screensaver
                  </label>
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text">
                        <i class="fas fa-moon"></i>
                      </span>
                    </div>
                    <select id="screensaverInput" name="display_screensaver" class="form-control selectpicker"
                            aria-describedby="screensaverInputHelp">
                        <?php
                        foreach (getScreensavers() as $key => $value) {
                            $selected = $display_screensaver == $key ? 'selected="selected"' : '';
                            echo '<option value="' . $key . '" ' . $selected . '>' . $value . '</option>';
                        }
                        ?>
                    </select>
                  </div>
                  <small id="screensaverInputHelp" class="form-text text-muted">
                    The screensaver to display in case the Raspberry Pi looses connection to the monitored PC
                  </small>
                </div>
              </div>

              <div class="form-row mt-2">
                <div class="col">
                  <label class="form-check-label form-label" for="screensaverDelayInput">
                    Delay
                  </label>
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text">
                        <i class="fas fa-stopwatch"></i>
                      </span>
                    </div>
                    <input class="form-control" type="number" name="display_delay" value="<?php echo $display_delay ?>"
                           min="0" id="screensaverDelayInput"
                        <?php if ($display_screensaver == 'disabled') echo 'disabled' ?>
                           aria-describedby="screensaverDelayInputHelp"
                    >
                    <span class="mt-2 ml-1 mr-3">minute(s)</span>
                  </div>
                  <small id="screensaverDelayInputHelp" class="form-text text-muted">
                    The delay in minutes before the screensaver is shown
                  </small>
                </div>
                <div class="col-auto">
                  <button id="screensaverPreviewButton" class="btn btn-outline-primary mt-4" type="button"
                      <?php if ($display_screensaver == 'disabled') echo 'disabled' ?>
                          title="Preview">
                    Preview
                  </button>
                </div>
              </div>

              <div class="button-row d-flex mt-4">
                <button class="btn btn-primary js-btn-prev" type="button" title="Prev">
                  <span><i class="fas fa-chevron-circle-left"></i></span> Prev
                </button>
                <button class="btn btn-primary ml-auto js-btn-next" type="button" title="Next">
                  Next <span><i class="fas fa-chevron-circle-right"></i></span>
                </button>
              </div>
            </div>
          </div>

          <!-- SUMMARY/CONFIRMATION -->
          <div class="multisteps-form__panel shadow p-4 rounded bg-white">
            <h3 class="multisteps-form__title text-center">Summary</h3>
            <div class="multisteps-form__content">

              <div class="form-row mt-4 confirmation-header">Localization</div>
              <div class="form-row">
                <div class="col-1"><span><i class="fas fa-globe-europe"></i></span></div>
                <div class="col-4 confirmation-title">Country</div>
                <div class="col" id="summaryCountry">
                </div>
              </div>
              <div class="form-row">
                <div class="col-1"><span><i class="fas fa-clock"></i></span></div>
                <div class="col-4 confirmation-title">Timezone</div>
                <div class="col" id="summaryTimezone">
                </div>
              </div>
              <hr>
              <div class="form-row mt-4 confirmation-header">Network</div>
              <div class="form-row">
                <div class="col-1"></div>
                <div class="col-4 confirmation-title">Mode</div>
                <div class="col" id="summaryNetworkMode">
                    <?php echo $network_mode == 'eth' ? 'Ethernet' : 'Wireless' ?>
                </div>
              </div>
              <div class="form-row">
                <div class="col-1"><span><i class="fas fa-wifi"></i></span></div>
                <div class="col-4 confirmation-title">SSID</div>
                <div class="col" id="summarySSID">
                    <?php echo $network_mode == 'eth' ? '<span><i class="fas fa-times"></i></span>' : '' ?>
                </div>
              </div>
              <div class="form-row">
                <div class="col-1"><span><i class="fas fa-key"></i></span></div>
                <div class="col-4 confirmation-title">Password</div>
                <div class="col" id="summaryPW">
                    <?php echo $network_mode == 'eth' ? '<span><i class="fas fa-times"></i></span>' : '' ?>
                </div>
              </div>
              <div class="form-row">
                <div class="col-1"><span><i class="fas fa-lock"></i></span></div>
                <div class="col-4 confirmation-title">Standard</div>
                <div class="col" id="summarySecurity">
                    <?php echo $network_mode == 'eth' ? '<span><i class="fas fa-times"></i></span>' : '' ?>
                </div>
              </div>
              <div class="form-row">
                <div class="col-1"><span><i class="fas fa-ghost"></i></span></div>
                <div class="col-4 confirmation-title">Hidden network</div>
                <div class="col" id="summaryHiddenNet">
                    <?php echo $network_mode == 'eth' ? '<span><i class="fas fa-times"></i></span>' : '' ?>
                </div>
              </div>
              <hr>
              <div class="form-row mt-2 confirmation-header">PC Connection</div>
              <div class="form-row">
                <div class="col-1"></div>
                <div class="col-4 confirmation-title">Mode</div>
                <div class="col" id="summaryPcConnMode"></div>
              </div>
              <div class="form-row" id="summaryConKeyRow">
                <div class="col-1"><span><i class="fas fa-search"></i></span></div>
                <div class="col-4 confirmation-title">Network name</div>
                <div class="col" id="summaryConKey"></div>
              </div>
              <div class="form-row" id="summaryIpRow">
                <div class="col-1"><span><i class="fas fa-at"></i></span></div>
                <div class="col-4 confirmation-title">IP address</div>
                <div class="col" id="summaryIp"></div>
              </div>
              <hr>
              <div class="form-row mt-2 confirmation-header">Screen</div>
              <div class="form-row">
                <div class="col-1"><span><i class="fas fa-desktop"></i></span></div>
                <div class="col-4 confirmation-title">Driver</div>
                <div class="col" id="summaryDriver"></div>
              </div>
              <div class="form-row">
                <div class="col-1"><span><i class="fas fa-sync-alt"></i></span></div>
                <div class="col-4 confirmation-title">Rotation</div>
                <div class="col" id="summaryRotation"></div>
              </div>
              <div class="form-row">
                <div class="col-1"><span><i class="fas fa-moon"></i></span></div>
                <div class="col-4 confirmation-title">Screensaver</div>
                <div class="col" id="summaryScreensaver"></div>
              </div>
              <div class="form-row">
                <div class="col-1"><span><i class="fas fa-stopwatch"></i></span></div>
                <div class="col-4 confirmation-title">Screensaver delay</div>
                <div class="col" id="summaryScreensaverDelay"></div>
              </div>

              <div class="row mt-4 alert alert-info font-weight-normal">
                <p class="m-0">
                  <span><i class="fas fa-exclamation-circle mr-2"></i></span>
                  After applying the new configuration the Raspberry Pi will reboot.
                </p>
              </div>
              <div class="button-row d-flex mt-4">
                <button class="btn btn-primary js-btn-prev" type="button" title="Prev">
                  <span><i class="fas fa-chevron-circle-left"></i></span> Prev
                </button>
                <a href="index.php" class="btn btn-danger ml-auto" role="button" title="Cancel">
                  <span><i class="fas fa-times"></i></span> Cancel
                </a>
                <button id="submitBtn" class="btn btn-success ml-4" type="submit" title="Apply">
                  <span><i class="fas fa-check"></i></span> Apply
                </button>
              </div>
            </div>
          </div>

        </form>
      </div>
    </div>
  </div>
</div>

<script>
  const stepButtons = $('.multisteps-form__progress-btn').toArray();
  const stepBar = $('.multisteps-form__progress')[0];
  const stepForm = $('.multisteps-form__form')[0];
  const stepPanels = $('.multisteps-form__panel').toArray();

  function removeClass(elements, clazz) {
    elements.forEach(elem => elem.classList.remove(clazz));
  }

  function findParent(element, parentClazz) {
    let currentNode = element;
    while (!currentNode.classList.contains(parentClazz)) {
      currentNode = currentNode.parentNode;
    }
    return currentNode;
  }

  function getActiveStepIndex(element) {
    return stepButtons.indexOf(element);
  }

  function setActiveStep(idx) {
    removeClass(stepButtons, 'js-active');
    stepButtons.forEach((e, i) => {
      if (i <= idx) {
        e.classList.add('js-active');
      }
    });
  }

  function getActivePanel() {
    stepPanels.forEach(e => {
      if (e.classList.contains('js-active')) {
        return e;
      }
    });
    return null;
  }

  function setActivePanel(activePanelNum) {
    removeClass(stepPanels, 'js-active');
    stepPanels.forEach((elem, index) => {
      if (index === activePanelNum) {
        elem.classList.add('js-active');
        setFormHeight(elem);
      }
    });
  }

  function formHeight(panel) {
    const activePanelHeight = panel.offsetHeight;
    stepForm.style.height = `${activePanelHeight}px`;
  }

  function setFormHeight() {
    const activePanel = getActivePanel();
    if (activePanel != null) {
      formHeight(activePanel);
    }
  }

  stepBar.addEventListener('click', e => {
    const eventTarget = e.target;
    if (!eventTarget.classList.contains('multisteps-form__progress-btn')) {
      return;
    }
    const stepIdx = getActiveStepIndex(eventTarget);
    setActiveStep(stepIdx);
    setActivePanel(stepIdx);
  });

  stepForm.addEventListener('click', e => {
    const eventTarget = e.target;
    if (!(eventTarget.classList.contains('js-btn-prev') || eventTarget.classList.contains('js-btn-next'))) {
      return;
    }
    const activePanel = findParent(eventTarget, 'multisteps-form__panel');
    let idx = stepPanels.indexOf(activePanel);
    if (eventTarget.classList.contains('js-btn-prev')) {
      idx--;
    } else {
      idx++;
    }
    setActiveStep(idx);
    setActivePanel(idx);
  });

  window.addEventListener('load', setFormHeight, false);
  window.addEventListener('resize', setFormHeight, false);

  const summaryPcConnMode = $('#summaryPcConnMode');
  const summaryConKey = $('#summaryConKey');
  const summaryIp = $('#summaryIp');
  const summaryScreenMode = $('#summaryScreenMode');
  const summaryScreensaver = $('#summaryScreensaver');
  const summaryScreensaverDelay = $('#summaryScreensaverDelay');

  // network
  <?php
  if ($network_mode == 'wifi') {
      echo "
            $('#summarySSID').html($('#ssidInput').val());
            $('#summaryPW').html(\"*\".repeat($('#passwordInput').val().length));
            $('#summarySecurity').html($('#wpaInput option:selected').text());
            $('#summaryHiddenNet').html($('#hiddenNetworkInput').prop('checked') ? 'Yes' : 'No');
        ";
  }
  ?>

  $('#summaryCountry').html($('#countryInput option:selected').text());
  $('#summaryTimezone').html($('#timeZoneInput option:selected').text());
  summaryPcConnMode.html($('#discovery1').prop('checked') ? 'Automatic discovery' : 'Static IP');
  summaryConKey.html($('#discovery1').prop('checked') ? $('#connectionKeyInput').val() : '<span><i class="fas fa-times"></i></span>');
  summaryIp.html($('#discovery1').prop('checked') ? '<span><i class="fas fa-times"></i></span>' : $('#staticIpInput').val());
  $('#summaryDriver').html($('#driverInput option:selected').text())
  $('#summaryRotation').html($('#rotationInput option:selected').text());
  summaryScreensaver.html($('#screensaverInput option:selected').text())
  summaryScreensaverDelay.html($('#screensaverInput option:selected').val() == 'disabled' ? '<span><i class="fas fa-times"></i></span>' : $('#screensaverDelayInput').val())

  $('#countryInput').on('change', _ => $('#summaryCountry').html($('#countryInput option:selected').text()));
  $('#timeZoneInput').on('change', _ => $('#summaryTimezone').html($('#timeZoneInput option:selected').text()));
  $('#ssidInput').on('change', _ => $('#summarySSID').html($('#ssidInput').val()));
  $('#passwordInput').on('change', _ => $('#summaryPW').html("*".repeat($('#passwordInput').val().length)));
  $('#wpaInput').on('change', _ => $('#summarySecurity').html($('#wpaInput option:selected').text()));
  $('#hiddenNetworkInput').on('change', _ => $('#summaryHiddenNet').html($('#hiddenNetworkInput').prop('checked') ? 'Yes' : 'No'));

  // PC config toggle
  let ipInput = $('#staticIpInput');
  let connKeyInput = $('#connectionKeyInput');
  $('#discovery1').on('click', _ => {
    ipInput.attr('disabled', 'disabled');
    ipInput.removeClass('border-primary');
    connKeyInput.removeAttr('disabled');
    connKeyInput.addClass('border-primary');
    summaryPcConnMode.html('Automatic discovery');
    summaryIp.html('<span><i class="fas fa-times"></i></span>');
    summaryConKey.html($('#connectionKeyInput').val());
  });
  $('#discovery2').on('click', _ => {
    connKeyInput.attr('disabled', 'disabled');
    connKeyInput.removeClass('border-primary');
    ipInput.removeAttr('disabled');
    ipInput.addClass('border-primary');
    summaryPcConnMode.html('Static IP');
    summaryConKey.html('<span><i class="fas fa-times"></i></span>');
    summaryIp.html($('#staticIpInput').val());
  });

  $('#staticIpInput').on('change', _ => summaryIp.html($('#staticIpInput').val()));
  $('#connectionKeyInput').on('change', _ => summaryConKey.html($('#connectionKeyInput').val()));


  $('#driverInput').on('change', _ => $('#summaryDriver').html($('#driverInput option:selected').text()));
  $('#rotationInput').on('change', _ => $('#summaryRotation').html($('#rotationInput option:selected').text()));
  let scrensaverDelayInput = $('#screensaverDelayInput');
  let previewBtn = $('#screensaverPreviewButton');
  $('#screensaverInput').on('change', _ => {
    summaryScreensaver.html($('#screensaverInput option:selected').text());
    let enabled = $('#screensaverInput option:selected').val() == 'disabled';
    if (enabled) {
      scrensaverDelayInput.attr('disabled', 'disabled');
      previewBtn.attr('disabled', 'disabled');
    } else {
      scrensaverDelayInput.removeAttr('disabled');
      previewBtn.removeAttr('disabled');
    }
    summaryScreensaverDelay.html(enabled ? '<span><i class="fas fa-times"></i></span>' : scrensaverDelayInput.val());
  });
  $('#screensaverDelayInput').on('change', _ => {
    let enabled = $('#screensaverInput option:selected').val() == 'disabled';
    summaryScreensaverDelay.html(enabled ? '<span><i class="fas fa-times"></i></span>' : scrensaverDelayInput.val());
  });


  $("#submitBtn").on("click", function () {
    $(this).prop("disabled", true);
    $(this).html('<span><i class="fas fa-spinner"></i></span> Applying...');
    $('#configForm').submit();
  });

  $("#screensaverPreviewButton").on("click", function () {
    var val = $('#screensaverInput').val();
    window.open('../screensavers/' + val, '_blank');
  });

</script>
</body>
</html>
