const fs = require("fs")
const path = require("path")
const {EOL} = require('os');

const outputName = process.env['TEMPLATE_OUTPUT_NAME']
const targetDir = path.join("src", outputName)
const preBootstrapPropertiesLaunchSettingsJson = process.env['PREBOOTSTRAP_PROPERTIES_LAUNCHSETTINGS_JSON']

/**
 * @typedef {Object} IISExpress
 * @property {String} [applicationUrl]
 * @property {Number} [sslPort]
 */
/**
 * @typedef {Object} IISSettings
 * @property {IISExpress?} [iisExpress]
 */
/**
 * @typedef {Object} LaunchSettings
 * @property {IISSettings} [iisSettings]
 */

/** @type {LaunchSettings?} */
const launchSettingsFilePath = path.join(targetDir, "Properties", "launchSettings.json")

fs.readFile(launchSettingsFilePath, { encoding: "utf8" }, (errRead, data) => {
  if (errRead) {
    process.exitCode = errRead.errno
    return
  }

  /** @type {String} */
  let dataString = data
  // Strip UTF-8 BOM (if present)
  dataString = dataString.replace(/^\uFEFF/, '')

  /** @type {LaunchSettings?} */
  const launchSettingsPreBootstrap = JSON.parse(preBootstrapPropertiesLaunchSettingsJson) || null
  /** @type {LaunchSettings?} */
  const launchSettingsCurrent = JSON.parse(dataString)

  const iisExpressPreBootstrap = (launchSettingsPreBootstrap && launchSettingsPreBootstrap.iisSettings ? launchSettingsPreBootstrap.iisSettings.iisExpress : null) || {}
  const iisExpressCurrent = (launchSettingsCurrent && launchSettingsCurrent.iisSettings ? launchSettingsCurrent.iisSettings.iisExpress : null) || {}

  if (iisExpressPreBootstrap.applicationUrl) {
    console.log("applicationUrl changed back to preBootstrap value", iisExpressPreBootstrap.applicationUrl);
    iisExpressCurrent.applicationUrl = iisExpressPreBootstrap.applicationUrl
  }
  if (iisExpressPreBootstrap.sslPort) {
    console.log("sslPort changed back to preBootstrap value", iisExpressPreBootstrap.sslPort);
    iisExpressCurrent.sslPort = iisExpressPreBootstrap.sslPort
  }

  let launchSettingsNewJson = JSON.stringify(launchSettingsCurrent, null, 2)
  launchSettingsNewJson = launchSettingsNewJson.replaceAll("\n", EOL)
  launchSettingsNewJson += EOL
  fs.writeFile(launchSettingsFilePath, launchSettingsNewJson, {
    encoding: "utf8"
  }, errWrite => {
    if (errWrite) {
      process.exitCode = errWrite.errno
      return
    }
  })
});
