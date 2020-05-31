//
//  SpotifyService.swift
//  Easify
//
//  Created by Muhammed Said Özcan on 16/05/2020.
//  Copyright © 2020 Muhammed Said Özcan. All rights reserved.
//

import Combine
import Foundation
import SpotifyLogin
import EasifyDefines

// MARK: - SpotifyCredentialsKeys
private enum SpotifyCredentialsKeys: String {
    case clientID = "client_id"
    case clientSecret = "client_secret"
    case redirectURL = "redirect_url"
}

// MARK: - SpotifyServiceError
/// `SpotifyServiceError` is used when an error occurs while constructing `SpotifyService` instance.
public enum SpotifyServiceError: Error {
    /// `.cannotReadRequiredKey` type of error is thrown when one of the required keys is not found or is able to read from the given property list file.
    case cannotReadRequiredKey(message: String)

    /// `.cannotInitializeUserDefaults` type of error is thrown when `UserDefaults(_suiteName:)` method returns nil
    case cannotInitializeUserDefaults(message: String)

    /// `description` property returns the message of an error type of `SpotifyServiceError`.
    var description: String {
        switch self {
        case .cannotReadRequiredKey(let message), .cannotInitializeUserDefaults(let message):
            return message
        }
    }

    /// `readingError` method is a conveinence method which is used to create `.cannotReadRequiredKey` type of errors.
    static func readingError(for key: String) -> SpotifyServiceError {
        return SpotifyServiceError.cannotReadRequiredKey(message: "Cannot read the required key: \(key)")
    }
}

// MARK: - SpotifyService
public class SpotifyService: ObservableObject {
    // MARK: - Properties
    /// The scopes which are requested upon login to Spotify API. They are as follows:
    public static let loginScopes: [Scope] = [
        .userReadTop,
        .playlistModifyPublic,
        .playlistReadPrivate,
        .playlistReadCollaborative,
        .userFollowRead,
        .userFollowModify
    ]
    private static let accessTokenKey = "nl.saidozcan.SpotifyService.accessTokenKey"
    private let clientID: String
    private let clientSecret: String
    private let redirectURL: URL
    @Published public private(set) var isLoggedIn: Bool = false
    @Published public private(set) var isAttemptingToLogin: Bool = false

    // MARK: - Lifecycle
    /// `SpotifyService` requires an instance of `PlistReaderService` which is constructed with the necessary plist file which includes `client_id`, `client_secret` and `redirect_uri` keys in it.
    public init(plistReaderService: PlistReaderService) throws {
        guard let clientID: String = plistReaderService.read(key: SpotifyCredentialsKeys.clientID.rawValue) else {
            throw SpotifyServiceError.readingError(for: SpotifyCredentialsKeys.clientID.rawValue)
        }
        self.clientID = clientID

        guard let clientSecret: String = plistReaderService.read(key: SpotifyCredentialsKeys.clientSecret.rawValue) else {
            throw SpotifyServiceError.readingError(for: SpotifyCredentialsKeys.clientSecret.rawValue)
        }
        self.clientSecret = clientSecret

        guard
            let redirectURLString: String = plistReaderService.read(key: SpotifyCredentialsKeys.redirectURL.rawValue),
            let redirectURL = URL(string: redirectURLString)
        else {
            throw SpotifyServiceError.readingError(for: SpotifyCredentialsKeys.redirectURL.rawValue)
        }
        self.redirectURL = redirectURL

        SpotifyLogin.shared.configure(clientID: clientID, clientSecret: clientSecret, redirectURL: redirectURL)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didLoginSuccessfully),
                                               name: .SpotifyLoginSuccessful,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public
    public func login(completion: ((String?, Error?) -> Void)? = nil) {
        self.isAttemptingToLogin = true
        SpotifyLogin.shared.getAccessToken { [weak self] (accessToken, error) in
            self?.isLoggedIn = (accessToken != nil)
            self?.isAttemptingToLogin = false
            completion?(accessToken, error)
        }
    }

    // MARK: - Private
    @objc private func didLoginSuccessfully() {
        SpotifyLogin.shared.getAccessToken { [weak self] (accessToken, _) in
            if let accessToken = accessToken {
                self?.isLoggedIn = true
                UserDefaults.standard.set(accessToken, forKey: EasifyConstants.StorageKeys.spotifyAccessToken)
            }
        }
    }
}
