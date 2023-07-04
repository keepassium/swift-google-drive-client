import Foundation
import KeychainAccess

public struct Keychain: Sendable {
  public typealias LoadCredentials = @Sendable () async -> Credentials?
  public typealias SaveCredentials = @Sendable (Credentials) async -> Void
  public typealias DeleteCredentials = @Sendable () async -> Void

  public init(
    loadCredentials: @escaping Keychain.LoadCredentials,
    saveCredentials: @escaping Keychain.SaveCredentials,
    deleteCredentials: @escaping Keychain.DeleteCredentials
  ) {
    self.loadCredentials = loadCredentials
    self.saveCredentials = saveCredentials
    self.deleteCredentials = deleteCredentials
  }

  public var loadCredentials: LoadCredentials
  public var saveCredentials: SaveCredentials
  public var deleteCredentials: DeleteCredentials
}

extension Keychain {
  public static func live(
    service: String =  "pl.darrarski.GoogleDriveClient"
  ) -> Keychain {
    let keychain = KeychainAccess.Keychain(service: service)
    let credentialsKey = "credentials"
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    return Keychain(
      loadCredentials: {
        guard let data = keychain[data: credentialsKey],
              let credentials = try? decoder.decode(Credentials.self, from: data)
        else { return nil }
        return credentials
      },
      saveCredentials: { credentials in
        guard let data = try? encoder.encode(credentials) else { return }
        keychain[data: credentialsKey] = data
      },
      deleteCredentials: {
        keychain[data: credentialsKey] = nil
      }
    )
  }
}
