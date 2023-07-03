import Dependencies
import GoogleDriveClient
import Logging
import SwiftUI

struct ContentView: View {
  let log = Logger(label: Bundle.main.bundleIdentifier!)
  @Dependency(\.googleDriveClientAuth) var auth
  @Dependency(\.googleDriveClientListFiles) var listFiles
  @Dependency(\.googleDriveClientCreateFile) var createFile
  @Dependency(\.googleDriveClientGetFile) var getFile
  @Dependency(\.googleDriveClientGetFileData) var getFileData
  @Dependency(\.googleDriveClientUpdateFile) var updateFile
  @Dependency(\.googleDriveClientDeleteFile) var deleteFile
  @State var isSignedIn = false
  @State var filesList: FilesList?
  @State var fileContentAlert: String?

  var body: some View {
    Form {
      authSection
      filesSection
    }
    .textSelection(.enabled)
    .navigationTitle("Example")
    .task {
      for await isSignedIn in auth.isSignedInStream() {
        self.isSignedIn = isSignedIn
      }
    }
    .onOpenURL { url in
      Task<Void, Never> {
        do {
          try await auth.handleRedirect(url)
        } catch {
          log.error("Auth.HandleRedirect failure", metadata: [
            "error": "\(error)",
            "localizedDescription": "\(error.localizedDescription)"
          ])
        }
        isSignedIn = await auth.isSignedIn()
      }
    }
    .alert(
      "File content",
      isPresented: Binding(
        get: { fileContentAlert != nil },
        set: { isPresented in
          if !isPresented {
            fileContentAlert = nil
          }
        }
      ),
      presenting: fileContentAlert,
      actions: { _ in Button("OK") {} },
      message: { Text($0) }
    )
  }

  var authSection: some View {
    Section("Auth") {
      if !isSignedIn {
        Text("You are signed out")

        Button {
          Task {
            await auth.signIn()
          }
        } label: {
          Text("Sign In")
        }
      } else {
        Text("You are signed in")

        Button(role: .destructive) {
          Task {
            await auth.signOut()
          }
        } label: {
          Text("Sign Out")
        }
      }
    }
  }

  @ViewBuilder
  var filesSection: some View {
    Section("Files") {
      Button {
        Task<Void, Never> {
          do {
            filesList = try await listFiles {
              $0.query = "trashed=false"
              $0.spaces = [.appDataFolder]
            }
          } catch {
            log.error("ListFiles failure", metadata: [
              "error": "\(error)",
              "localizedDescription": "\(error.localizedDescription)"
            ])
          }
        }
      } label: {
        Text("List Files")
      }

      Button {
        Task<Void, Never> {
          do {
            let dateText = Date().formatted(date: .complete, time: .complete)
            _ = try await createFile(
              name: "test.txt",
              spaces: "appDataFolder",
              mimeType: "text/plain",
              parents: ["appDataFolder"],
              data: "Hello, World!\nCreated at \(dateText)".data(using: .utf8)!
            )
          } catch {
            log.error("CreateFile failure", metadata: [
              "error": "\(error)",
              "localizedDescription": "\(error.localizedDescription)"
            ])
          }
        }
      } label: {
        Text("Create File")
      }
    }

    if let filesList {
      if filesList.files.isEmpty {
        Section {
          Text("No files")
        }
      } else {
        ForEach(filesList.files) { file in
          fileSection(file)
        }
      }
    }
  }

  func fileSection(_ file: File) -> some View {
    Section {
      VStack(alignment: .leading) {
        Text("ID").font(.caption).foregroundColor(.secondary)
        Text(file.id)
      }

      VStack(alignment: .leading) {
        Text("Name").font(.caption).foregroundColor(.secondary)
        Text(file.name)
      }

      VStack(alignment: .leading) {
        Text("Created Time").font(.caption).foregroundColor(.secondary)
        Text(file.createdTime.formatted(date: .complete, time: .complete))
      }

      VStack(alignment: .leading) {
        Text("Modified Time").font(.caption).foregroundColor(.secondary)
        Text(file.modifiedTime.formatted(date: .complete, time: .complete))
      }

      Button {
        Task<Void, Never> {
          do {
            let file = try await getFile(fileId: file.id)
            if let files = filesList?.files {
              filesList?.files = files.map {
                $0.id == file.id ? file : $0
              }
            }
          } catch {
            log.error("GetFile failure", metadata: [
              "error": "\(error)",
              "localizedDescription": "\(error.localizedDescription)"
            ])
          }
        }
      } label: {
        Text("Get File")
      }

      Button {
        Task<Void, Never> {
          do {
            let params = GetFileData.Params(fileId: file.id)
            let data = try await getFileData(params)
            if let string = String(data: data, encoding: .utf8) {
              fileContentAlert = string
            } else {
              fileContentAlert = data.base64EncodedString()
            }
          } catch {
            log.error("GetFileData failure", metadata: [
              "error": "\(error)",
              "localizedDescription": "\(error.localizedDescription)"
            ])
          }
        }
      } label: {
        Text("Get File Data")
      }

      Button {
        Task<Void, Never> {
          do {
            var data = try await getFileData(fileId: file.id)
            let dateText = Date().formatted(date: .complete, time: .complete)
            data.append("\nUpdated at \(dateText)".data(using: .utf8)!)
            _ = try await updateFile(
              fileId: file.id,
              data: data,
              mimeType: "text/plain"
            )
          } catch {
            log.error("UpdateFile failure", metadata: [
              "error": "\(error)",
              "localizedDescription": "\(error.localizedDescription)"
            ])
          }
        }
      } label: {
        Text("Update File")
      }

      Button(role: .destructive) {
        Task<Void, Never> {
          do {
            try await deleteFile(fileId: file.id)
            if let files = filesList?.files {
              filesList?.files = files.filter { $0.id != file.id }
            }
          } catch {
            log.error("DeleteFile failure", metadata: [
              "error": "\(error)",
              "localizedDescription": "\(error.localizedDescription)"
            ])
          }
        }
      } label: {
        Text("Delete File")
      }
    }
  }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
#endif

extension GoogleDriveClient.Config: DependencyKey {
  public static let liveValue = Config(
    clientID: "437442953929-vk9agcivr59cldl92jqaiqdvlncpuh2v.apps.googleusercontent.com",
    authScope: "https://www.googleapis.com/auth/drive.appdata",
    redirectURI: "com.googleusercontent.apps.437442953929-vk9agcivr59cldl92jqaiqdvlncpuh2v://"
  )
}
