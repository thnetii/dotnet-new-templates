import { readFile, writeFile } from "fs"
import { join } from "path"

const outputName = process.env['TEMPLATE_OUTPUT_NAME']
const targetDir = join("src", outputName)
const preBootstrapPropertiesLaunchSettingsJson = process.env['PREBOOTSTRAP_PROPERTIES_LAUNCHSETTINGS_JSON']

/**
 * @typedef {Object} IISExpress
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
const launchSettingsPreBootstrap = JSON.parse(preBootstrapPropertiesLaunchSettingsJson) || null
const launchSettingsFilePath = join(targetDir, "Properties", "launchSettings.json")

readFile(launchSettingsFilePath, { encoding: "utf8" }, (errRead, data) => {
  if (errRead) {
    process.exitCode = errRead.errno
    return
  }

  /** @type {LaunchSettings?} */
  const launchSettingsCurrent = JSON.parse(data)
  if (launchSettingsPreBootstrap && launchSettingsPreBootstrap.iisSettings && launchSettingsPreBootstrap.iisSettings.iisExpress && launchSettingsPreBootstrap.iisSettings.iisExpress.sslPort) {
    const iisSettingsCurrent = (launchSettingsCurrent && launchSettingsCurrent.iisSettings ? launchSettingsCurrent.iisSettings.iisExpress : null) || {}
    iisSettingsCurrent.sslPort = launchSettingsPreBootstrap.iisSettings.iisExpress.sslPort
  }

  const launchSettingsNewJson = JSON.stringify(launchSettingsCurrent, null, 2)
  writeFile(launchSettingsFilePath, launchSettingsNewJson, {
    encoding: "utf8"
  }, errWrite => {
    if (errWrite) {
      process.exitCode = errWrite.errno
      return
    }
  })
});
