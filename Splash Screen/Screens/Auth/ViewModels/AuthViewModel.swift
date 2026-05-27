//
//  AuthViewModel.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 05/01/26.
//
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import GoogleSignIn
import FirebaseCore
import AuthenticationServices
import CryptoKit
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var isError: Bool = false
    
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    // Apple Sign In
    private var currentNonce: String?
    
    init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateHandler = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.userSession = user
                if user != nil {
                    await self?.fetchCurrentUser()
                    await self?.loadUserData()
                } else {
                    self?.currentUser = nil
                }
            }
        }
    }
    
    private func loadUserData() async {
        await FollowService.shared.fetchFollowingList()
        await UserJamsService.shared.fetchAllUserJams()
        await RepostService.shared.fetchMyReposts()
        await MyJamsService.shared.fetchMyJams()
        RepostService.shared.startListening()
    }
    
    func createUser(email: String, fullname: String, username: String, password: String) async {
        do {
            if try await usernameExists(username) { return }
            
            let result = try await auth.createUser(withEmail: email, password: password)
            try await storeUserInFirestore(uid: result.user.uid, email: email, fullname: fullname, username: username)
            
            self.userSession = result.user
            await fetchCurrentUser()
            await loadUserData()
        } catch {
            isError = true
        }
    }
    
    func fetchCurrentUser() async {
        guard let uid = auth.currentUser?.uid else { return }
        do {
            let doc = try await firestore.collection("users").document(uid).getDocument()
            self.currentUser = try doc.data(as: User.self)
        } catch {}
    }
    
    func storeUserInFirestore(uid: String, email: String, fullname: String, username: String) async throws {
        let user = User(uid: uid, email: email, fullName: fullname, username: username, joinedDate: Date())
        try firestore.collection("users").document(uid).setData(from: user)
    }
    
    func usernameExists(_ username: String) async throws -> Bool {
        let snapshot = try await firestore.collection("users")
            .whereField("username", isEqualTo: username).getDocuments()
        return !snapshot.documents.isEmpty
    }
    
    func getEmailFromUsername(_ username: String) async throws -> String {
        let snapshot = try await firestore.collection("users")
            .whereField("username", isEqualTo: username).getDocuments()
        guard let doc = snapshot.documents.first,
              let email = doc.data()["email"] as? String else {
            throw NSError(domain: "AuthError", code: 404)
        }
        return email
    }

    func signIn(emailOrUsername: String, password: String) async {
        do {
            var email = emailOrUsername
            if !emailOrUsername.contains("@") {
                email = try await getEmailFromUsername(emailOrUsername)
            }
            
            let result = try await auth.signIn(withEmail: email, password: password)
            self.userSession = result.user
            await fetchCurrentUser()
            await loadUserData()
            self.isError = false
        } catch {
            self.isError = true
        }
    }
    
    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else { return }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            let authResult = try await auth.signIn(with: credential)
            
            self.userSession = authResult.user
            
            let uid = authResult.user.uid
            let userRef = firestore.collection("users").document(uid)
            
            if !(try await userRef.getDocument()).exists {
                try await storeUserInFirestore(
                    uid: uid,
                    email: authResult.user.email ?? "",
                    fullname: authResult.user.displayName ?? "User",
                    username: authResult.user.email?.components(separatedBy: "@").first ?? uid
                )
            }
            
            await fetchCurrentUser()
            await loadUserData()
        } catch {
            isError = true
        }
    }
    
    // MARK: - Sign In with Apple
    func signInWithApple() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        
        let delegate = AppleSignInDelegate { [weak self] result in
            Task { @MainActor in
                await self?.handleAppleSignInResult(result)
            }
        }
        
        // Keep delegate alive
        objc_setAssociatedObject(authorizationController, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        
        authorizationController.delegate = delegate
        authorizationController.presentationContextProvider = window.rootViewController as? ASAuthorizationControllerPresentationContextProviding
        authorizationController.performRequests()
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                isError = true
                return
            }
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            do {
                let authResult = try await auth.signIn(with: credential)
                self.userSession = authResult.user
                
                let uid = authResult.user.uid
                let userRef = firestore.collection("users").document(uid)
                
                // Check if user exists
                if !(try await userRef.getDocument()).exists {
                    // Get name from Apple credential or use default
                    var fullName = "User"
                    if let givenName = appleIDCredential.fullName?.givenName {
                        fullName = givenName
                        if let familyName = appleIDCredential.fullName?.familyName {
                            fullName += " \(familyName)"
                        }
                    }
                    
                    // Get email or generate username
                    let email = appleIDCredential.email ?? authResult.user.email ?? ""
                    let username = email.components(separatedBy: "@").first ?? "user_\(uid.prefix(8))"
                    
                    try await storeUserInFirestore(
                        uid: uid,
                        email: email,
                        fullname: fullName,
                        username: username
                    )
                }
                
                await fetchCurrentUser()
                await loadUserData()
                
            } catch {
                print("❌ Apple Sign In Error: \(error)")
                isError = true
            }
            
        case .failure(let error):
            print("❌ Apple Sign In Failed: \(error)")
            isError = true
        }
    }
    
    // MARK: - Apple Sign In Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func signOut() {
        AudioPlayerManager.shared.stop()
        
        try? auth.signOut()
        self.userSession = nil
        self.currentUser = nil
        
        FollowService.shared.resetOnLogout()
        UserJamsService.shared.resetOnLogout()
        RepostService.shared.resetOnLogout()
        MyJamsService.shared.resetOnLogout()
        
        cleanupPremiumUserDefaults()
    }
    
    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let user = auth.currentUser,
              let _ = currentUser else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        let uid = user.uid
        
        // Stop all services
        AudioPlayerManager.shared.stop()
        RepostService.shared.stopListening()
        
        // 1. Delete user's jams and their audio/artwork from Storage
        await deleteUserJams(uid: uid)
        
        // 2. Delete user's profile and banner images from Storage
        await deleteUserImages(uid: uid)
        
        // 3. Delete user's subcollections in Firestore
        await deleteUserSubcollections(uid: uid)
        
        // 4. Delete user's reposts
        await deleteUserReposts(uid: uid)
        
        // 5. Delete notifications related to user
        await deleteUserNotifications(uid: uid)
        
        // 6. Delete user document from Firestore
        try await firestore.collection("users").document(uid).delete()
        
        // 7. Delete Firebase Auth account (MUST be last and handle re-auth)
        do {
            try await user.delete()
            print("✅ Firebase Auth account deleted")
        } catch let error as NSError {
            // Si requiere re-autenticación, el código es 17014
            if error.code == 17014 || error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                print("⚠️ Requires recent login - attempting to delete anyway")
                // El usuario necesitará hacer logout y la cuenta quedará huérfana
                // pero sin datos en Firestore
                throw NSError(
                    domain: "AuthError",
                    code: 17014,
                    userInfo: [NSLocalizedDescriptionKey: "Please sign out and sign in again, then try deleting your account."]
                )
            } else {
                throw error
            }
        }
        
        // 8. Reset local state
        await MainActor.run {
            self.userSession = nil
            self.currentUser = nil
            
            FollowService.shared.resetOnLogout()
            UserJamsService.shared.resetOnLogout()
            RepostService.shared.resetOnLogout()
            MyJamsService.shared.resetOnLogout()
            NotificationService.shared.resetOnLogout()
        }
        
        print("✅ Account deleted successfully")
    }
    
    // MARK: - Delete Account with Re-authentication (Email/Password)
    func deleteAccountWithReauth(password: String) async throws {
        guard let user = auth.currentUser,
              let email = user.email,
              let _ = currentUser else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        // Re-authenticate first
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
        
        // Now delete
        try await deleteAccount()
    }
    
    // MARK: - Delete Account with Google Re-authentication
    func deleteAccountWithGoogleReauth() async throws {
        guard let user = auth.currentUser,
              let _ = currentUser,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController,
              let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        // Re-authenticate with Google
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "AuthError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to get Google token"])
        }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        try await user.reauthenticate(with: credential)
        
        // Now delete
        try await deleteAccount()
    }
    
    // MARK: - Delete Account with Apple Re-authentication
    func deleteAccountWithAppleReauth() async throws {
        guard let user = auth.currentUser,
              let _ = currentUser else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        // Use continuation to wait for Apple Sign In result
        let authorization = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            let delegate = AppleSignInDelegate { result in
                switch result {
                case .success(let auth):
                    continuation.resume(returning: auth)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            let authController = ASAuthorizationController(authorizationRequests: [request])
            objc_setAssociatedObject(authController, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            authController.delegate = delegate
            authController.performRequests()
        }
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw NSError(domain: "AuthError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to get Apple credential"])
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        try await user.reauthenticate(with: credential)
        
        // Now delete
        try await deleteAccount()
    }
    
    // MARK: - Delete Helpers
    
    private func deleteUserJams(uid: String) async {
        do {
            let jamsSnapshot = try await firestore.collection("jamsPremium")
                .whereField("userId", isEqualTo: uid)
                .getDocuments()
            
            let storage = Storage.storage()
            
            for doc in jamsSnapshot.documents {
                let data = doc.data()
                let jamId = doc.documentID
                
                // Delete audio file
                if let audioUrl = data["audioUrl"] as? String,
                   let audioPath = extractStoragePath(from: audioUrl) {
                    try? await storage.reference().child(audioPath).delete()
                }
                
                // Delete artwork
                if let artworkUrl = data["artworkUrl"] as? String,
                   let artworkPath = extractStoragePath(from: artworkUrl) {
                    try? await storage.reference().child(artworkPath).delete()
                }
                
                // Delete jam document
                try? await firestore.collection("jamsPremium").document(jamId).delete()
                
                // Delete from user's myJams subcollection
                try? await firestore.collection("users").document(uid)
                    .collection("myJams").document(jamId).delete()
            }
            
            print("🗑️ Deleted \(jamsSnapshot.documents.count) jams")
        } catch {
            print("⚠️ Error deleting jams: \(error)")
        }
    }
    
    private func deleteUserImages(uid: String) async {
        let storage = Storage.storage()
        
        try? await storage.reference().child("profile_images/\(uid)").delete()
        try? await storage.reference().child("banner_images/\(uid)").delete()
        
        print("🗑️ Deleted user images")
    }
    
    private func deleteUserSubcollections(uid: String) async {
        let subcollections = [
            "following",
            "followers",
            "likedJams",
            "savedJams",
            "likedJamsPremium",
            "savedJamsPremium",
            "reposts",
            "myJams"
        ]
        
        for collection in subcollections {
            do {
                let snapshot = try await firestore.collection("users")
                    .document(uid)
                    .collection(collection)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    try? await doc.reference.delete()
                }
            } catch {
                print("⚠️ Error deleting \(collection): \(error)")
            }
        }
        
        print("🗑️ Deleted user subcollections")
    }
    
    private func deleteUserReposts(uid: String) async {
        do {
            let repostsSnapshot = try await firestore.collection("reposts")
                .whereField("odei", isEqualTo: uid)
                .getDocuments()
            
            for doc in repostsSnapshot.documents {
                try? await doc.reference.delete()
            }
            
            let jamRepostsSnapshot = try await firestore.collection("jamReposts")
                .whereField("userId", isEqualTo: uid)
                .getDocuments()
            
            for doc in jamRepostsSnapshot.documents {
                try? await doc.reference.delete()
            }
            
            print("🗑️ Deleted user reposts")
        } catch {
            print("⚠️ Error deleting reposts: \(error)")
        }
    }
    
    private func deleteUserNotifications(uid: String) async {
        do {
            let toSnapshot = try await firestore.collection("notifications")
                .whereField("toUserId", isEqualTo: uid)
                .getDocuments()
            
            for doc in toSnapshot.documents {
                try? await doc.reference.delete()
            }
            
            let fromSnapshot = try await firestore.collection("notifications")
                .whereField("fromUserId", isEqualTo: uid)
                .getDocuments()
            
            for doc in fromSnapshot.documents {
                try? await doc.reference.delete()
            }
            
            print("🗑️ Deleted user notifications")
        } catch {
            print("⚠️ Error deleting notifications: \(error)")
        }
    }
    
    private func extractStoragePath(from url: String) -> String? {
        guard let range = url.range(of: "/o/") else { return nil }
        var path = String(url[range.upperBound...])
        
        if let queryRange = path.range(of: "?") {
            path = String(path[..<queryRange.lowerBound])
        }
        
        return path.removingPercentEncoding
    }
    
    
    private func cleanupPremiumUserDefaults() {
            let defaults = UserDefaults.standard
            
            // Limpiar TODOS los datos de suscripción
            defaults.removeObject(forKey: "premium_subscription_status")
            defaults.removeObject(forKey: "premium_product_id")
            defaults.removeObject(forKey: "premium_purchase_date")
            defaults.removeObject(forKey: "premium_expiration_date")
            defaults.removeObject(forKey: "premium_is_trial")
            defaults.removeObject(forKey: "premium_transaction_id")
            defaults.removeObject(forKey: "has_ever_subscribed")
            
            print("🗑️ Premium UserDefaults limpiados al cerrar sesión")
        }
    
    deinit {
        if let handler = authStateHandler {
            auth.removeStateDidChangeListener(handler)
        }
    }
}

// MARK: - Apple Sign In Delegate
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (Result<ASAuthorization, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}




