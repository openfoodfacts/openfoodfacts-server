<?php
use MediaWiki\Session\SessionInfo;
use MediaWiki\Session\UserInfo;
use MediaWiki\Session\SessionBackend;

class ProductOpenerSessionProvider extends MediaWiki\Session\SessionProvider {

	/**
	 * Provide session info for a request
	 *
	 * If no session exists for the request, return null. Otherwise return an
	 * SessionInfo object identifying the session.
	 *
	 * If multiple SessionProviders provide sessions, the one with highest
	 * priority wins. In case of a tie, an exception is thrown.
	 * SessionProviders are encouraged to make priorities user-configurable
	 * unless only max-priority makes sense.
	 *
	 * @warning This will be called early in the MediaWiki setup process,
	 *  before $wgUser, $wgLang, $wgOut, $wgParser, $wgTitle, and corresponding
	 *  pieces of the main RequestContext are set up! If you try to use these,
	 *  things *will* break.
	 * @note The SessionProvider must not attempt to auto-create users.
	 *  MediaWiki will do this later (when it's safe) if the chosen session has
	 *  a user with a valid name but no ID.
	 * @protected For use by \MediaWiki\Session\SessionManager only
	 * @param WebRequest $request
	 * @return SessionInfo|null
	 */
	public function provideSessionInfo( WebRequest $request ) {
		$cookie = $_COOKIE['session'];
		if ( $cookie === null || $cookie === '' || $cookie === 'deleted') {
			$this->logger->notice('No session cookie found for request.');
			return null;
		}

		$this->logger->debug('Session cookie found for request: {cookie}.',
		[
			'cookie' => $cookie
		]);

		$chunks = array_chunk(preg_split('/&/', $cookie), 2);
		$data = array_combine(array_column($chunks, 0), array_column($chunks, 1));

		try {
			$response = Http::post( 'https://world.openfoodfacts.org/cgi/sso.pl',  [ "postData" => $data ] );
			if ($response === false) {
				$this->logger->notice('SSO response for cookie {cookie} was {response}.',
				[
					'cookie' => $cookie,
					'response' => $response,
				]);
				return null;
			}

			$this->logger->debug('SSO response for cookie {cookie} was {response}.',
			[
				'cookie' => $cookie,
				'response' => $response,
			]);
			$obj = json_decode($response);

			$user = User::newFromName( $obj->{'user_id'} );
			if ( $user === false ) {
				$this->logger->info('User::newFromName for {userId} returned false.',
				[
					'cookie' => $cookie,
					'response' => $response,
					'userId' => $obj->{'user_id'},
					'user' => $user,
				]);
				return null;
			}

			if ( $user->getID() == 0 ) {
				$this->logger->notice('User not found (id == 0), trying to create new user.',
				[
					'cookie' => $cookie,
					'response' => $response,
					'userId' => $obj->{'user_id'},
					'user' => $user,
				]);
				$am = AuthManager::singleton();
				$user->setRealName($obj->{'name'});
				$user->setEmail($obj->{'email'});
				AuthManager::singleton()->autoCreateUser($user, self::AUTOCREATE_SOURCE_SESSION, false);
			}

			$info['userInfo'] = UserInfo::newFromUser( $user, true );
			$info['provider'] = $this;
			return new SessionInfo( $this->priority, $info );
		} catch (HttpException $ex) {
			$this->logger->error(
				'Could not retrieve user information for session cookie.',
				[
					'cookie' => $cookie
				]
			);
		}
	}

	/**
	 * Validate a loaded SessionInfo and refresh provider metadata
	 *
	 * This is similar in purpose to the 'SessionCheckInfo' hook, and also
	 * allows for updating the provider metadata. On failure, the provider is
	 * expected to write an appropriate message to its logger.
	 *
	 * @protected For use by \MediaWiki\Session\SessionManager only
	 * @param SessionInfo $info Any changes by mergeMetadata() will already be reflected here.
	 * @param WebRequest $request
	 * @param array|null &$metadata Provider metadata, may be altered.
	 * @return bool Return false to reject the SessionInfo after all.
	 */
	public function refreshSessionInfo( SessionInfo $info, WebRequest $request, &$metadata ) {
		return true;
	}

	/**
	 * Indicate whether self::persistSession() can save arbitrary session IDs
	 *
	 * If false, any session passed to self::persistSession() will have an ID
	 * that was originally provided by self::provideSessionInfo().
	 *
	 * If true, the provider may be passed sessions with arbitrary session IDs,
	 * and will be expected to manipulate the request in such a way that future
	 * requests will cause self::provideSessionInfo() to provide a SessionInfo
	 * with that ID.
	 *
	 * For example, a session provider for OAuth would function by matching the
	 * OAuth headers to a particular user, and then would use self::hashToSessionId()
	 * to turn the user and OAuth client ID (and maybe also the user token and
	 * client secret) into a session ID, and therefore can't easily assign that
	 * user+client a different ID. Similarly, a session provider for SSL client
	 * certificates would function by matching the certificate to a particular
	 * user, and then would use self::hashToSessionId() to turn the user and
	 * certificate fingerprint into a session ID, and therefore can't easily
	 * assign a different ID either. On the other hand, a provider that saves
	 * the session ID into a cookie can easily just set the cookie to a
	 * different value.
	 *
	 * @protected For use by \MediaWiki\Session\SessionBackend only
	 * @return bool
	 */
	public function persistsSessionId() {
		return false;
	}

	/**
	 * Indicate whether the user associated with the request can be changed
	 *
	 * If false, any session passed to self::persistSession() will have a user
	 * that was originally provided by self::provideSessionInfo(). Further,
	 * self::provideSessionInfo() may only provide sessions that have a user
	 * already set.
	 *
	 * If true, the provider may be passed sessions with arbitrary users, and
	 * will be expected to manipulate the request in such a way that future
	 * requests will cause self::provideSessionInfo() to provide a SessionInfo
	 * with that ID. This can be as simple as not passing any 'userInfo' into
	 * SessionInfo's constructor, in which case SessionInfo will load the user
	 * from the saved session's metadata.
	 *
	 * For example, a session provider for OAuth or SSL client certificates
	 * would function by matching the OAuth headers or certificate to a
	 * particular user, and thus would return false here since it can't
	 * arbitrarily assign those OAuth credentials or that certificate to a
	 * different user. A session provider that shoves information into cookies,
	 * on the other hand, could easily do so.
	 *
	 * @protected For use by \MediaWiki\Session\SessionBackend only
	 * @return bool
	 */
	public function canChangeUser() {
		return false;
	}

	/**
	 * Persist a session into a request/response
	 *
	 * For example, you might set cookies for the session's ID, user ID, user
	 * name, and user token on the passed request.
	 *
	 * To correctly persist a user independently of the session ID, the
	 * provider should persist both the user ID (or name, but preferably the
	 * ID) and the user token. When reading the data from the request, it
	 * should construct a User object from the ID/name and then verify that the
	 * User object's token matches the token included in the request. Should
	 * the tokens not match, an anonymous user *must* be passed to
	 * SessionInfo::__construct().
	 *
	 * When persisting a user independently of the session ID,
	 * $session->shouldRememberUser() should be checked first. If this returns
	 * false, the user token *must not* be saved to cookies. The user name
	 * and/or ID may be persisted, and should be used to construct an
	 * unverified UserInfo to pass to SessionInfo::__construct().
	 *
	 * A backend that cannot persist sesison ID or user info should implement
	 * this as a no-op.
	 *
	 * @protected For use by \MediaWiki\Session\SessionBackend only
	 * @param SessionBackend $session Session to persist
	 * @param WebRequest $request Request into which to persist the session
	 */
	public function persistSession( SessionBackend $session, WebRequest $request ) {}

	/**
	 * Remove any persisted session from a request/response
	 *
	 * For example, blank and expire any cookies set by self::persistSession().
	 *
	 * A backend that cannot persist sesison ID or user info should implement
	 * this as a no-op.
	 *
	 * @protected For use by \MediaWiki\Session\SessionManager only
	 * @param WebRequest $request Request from which to remove any session data
	 */
	public function unpersistSession( WebRequest $request ) {}

}
