import struct Foundation.Data
import class Foundation.JSONEncoder
import class Foundation.ProcessInfo
import typealias Foundation.TimeInterval

enum ShowProcInfErr: Error {
  case invalidJson
}

func thermalStateToString(_ state: ProcessInfo.ThermalState) -> String {
  switch state {
  case .nominal: return "nominal"
  case .fair: return "fair"
  case .serious: return "serious"
  case .critical: return "critical"
  @unknown default: return "UNKNOWN THERMAL STATE"
  }
}

struct ProcInfo: Codable {
  var id: String
  var isMacCatalystApp: Bool
  var isiOSAppOnMac: Bool
  var processIdentifier: Int32
  var processName: String

  var userName: String
  var fullUserName: String

  var automaticTerminationSupportEnabled: Bool

  var hostName: String
  var operatingSystemVersionString: String

  var processorCount: Int
  var activeProcessorCount: Int
  var physicalMemory: UInt64
  var systemUptime: TimeInterval

  var isLowPowerModeEnabled: Bool

  var thermalState: String

  static func fromRaw(raw: ProcessInfo) -> Self {
    Self(
      id: raw.globallyUniqueString,
      isMacCatalystApp: raw.isMacCatalystApp,
      isiOSAppOnMac: raw.isiOSAppOnMac,
      processIdentifier: raw.processIdentifier,
      processName: raw.processName,

      userName: raw.userName,
      fullUserName: raw.fullUserName,

      automaticTerminationSupportEnabled: raw.automaticTerminationSupportEnabled,

      hostName: raw.hostName,
      operatingSystemVersionString: raw.operatingSystemVersionString,

      processorCount: raw.processorCount,
      activeProcessorCount: raw.activeProcessorCount,
      physicalMemory: raw.physicalMemory,
      systemUptime: raw.systemUptime,

      isLowPowerModeEnabled: raw.isLowPowerModeEnabled,

      thermalState: thermalStateToString(raw.thermalState)
    )
  }

  func toJSON(encoder: JSONEncoder) -> Result<Data, Error> {
    Result(catching: {
      try encoder.encode(self)
    })
  }
}

func data2string(_ data: Data) -> Result<String, Error> {
  let ostr: String? = String(data: data, encoding: .utf8)
  guard let s = ostr else {
    return .failure(ShowProcInfErr.invalidJson)
  }

  return .success(s)
}

typealias IO<T> = () -> Result<T, Error>

func Of<T>(_ t: T) -> IO<T> {
  return {
    .success(t)
  }
}

func Bind<T, U>(
  _ i: @escaping IO<T>,
  _ f: @escaping (T) -> IO<U>
) -> IO<U> {
  return {
    let rt: Result<T, Error> = i()
    return rt.flatMap {
      let t: T = $0
      return f(t)()
    }
  }
}

func Lift<T, U>(_ pure: @escaping (T) -> Result<U, Error>) -> (T) -> IO<U> {
  return {
    let t: T = $0
    return {
      pure(t)
    }
  }
}

func printString(_ s: String) -> IO<Void> {
  return {
    print("\( s )")
    return .success(())
  }
}

@main
struct ShowProcessInfo {
  static func main() {
    let raw: IO<ProcessInfo> = Of(ProcessInfo.processInfo)

    let pinf: IO<ProcInfo> = Bind(
      raw,
      Lift({
        let r: ProcessInfo = $0
        return .success(ProcInfo.fromRaw(raw: r))
      })
    )

    let enc: JSONEncoder = JSONEncoder()

    let pijson: IO<Data> = Bind(
      pinf,
      Lift({
        let p: ProcInfo = $0
        return p.toJSON(encoder: enc)
      })
    )

    let pjstr: IO<String> = Bind(
      pijson,
      Lift({
        let d: Data = $0
        return data2string(d)
      })
    )

    let procinfo2json2stdout: IO<Void> = Bind(
      pjstr,
      printString
    )

    let rslt: Result<_, _> = procinfo2json2stdout()

    do {
      try rslt.get()
    } catch {
      print("\( error )")
    }
  }
}
