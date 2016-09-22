<?php
/*
 * CASification script for MediaWiki 1.13 with phpCAS 0.6.0-RC5
 * 
 * Requires phpCAS: http://www.ja-sig.org/wiki/display/CASC/phpCAS
 * Install by adding this line to LocalSetting.php:
 *  require_once("$IP/extensions/CASAuth/CASAuth.php");
 * 
 * Remember to edit the configuration below!
 * Also consider restricting normal account creation:
 *  http://www.mediawiki.org/wiki/Manual:Preventing_access#Restrict_account_creation
 * You can disable the IP in the header which appears after logging out:
 *  http://www.mediawiki.org/wiki/Manual:$wgShowIPinHeader
 * 
 * 
 * Author: Ioannis Yessios (ioannis [dot] yessios [at] yale [dot] edu)
 * Worked with the code by Christophe Naslain ( chris [dot] n [at] free [dot] fr)
 * Which was based on the original script using CAS Utils by Victor Chen (Yvchen [at] sfu [dot] ca)
 * Cleaned up and bugfixed by Stefan Sundin (recover89@gmail.com)
 */
 error_log("Ini\n", 3, "/var/tmp/mes-erreurs.log");
 
$wgExtensionCredits["other"][] = array(
        "name"        => "CASAuth",
        "version"     => "1.1e",
        "author"      => "Ioannis Yessios",
        "url"         => "http://www.mediawiki.org/wiki/Extension:CASAuthentication",
        "description" => "Overrides MediaWiki's Authentication and implements Central Authentication Service (CAS) Authentication"
);
 
//--------------------------------------------------------------------------
// Configuration Variables
//--------------------------------------------------------------------------
 
$CASAuth = array(
        "phpCAS"         => "$IP/extensions/CASAuth/CAS", // Path to phpCAS directory.
        "Server"         => "secure.its.yale.edu",        // Address to CAS server.
        "Port"           => 443,                          // Port to CAS server. Default: 443.
        "Url"            => "/cas/servlet/",              // Subdir to CAS authentication.
        "Version"        => "1.0",                        // CAS version, should be either 1.0 or 2.0.
        "CreateAccounts" => true,                         // Should CASAuth create accounts on the wiki? Should be true unless all accounts already exists on the wiki!
        "PwdSecret"      => "nimporte quoi", // A random string that is used when generating the MediaWiki password for this user. YOU SHOULD EDIT THIS TO A VERY RANDOM STRING! YOU SHOULD ALSO KEEP THIS A SECRET!
        "EmailDomain"    => "yale.edu",                   // The default domain for new users email address (is appended to the username). #OBSOLETE
        "RememberMe"     => true,                         // Log in users with the 'Remember me' option.
);
 
//--------------------------------------------------------------------------
// CASAuth
//--------------------------------------------------------------------------
 
// Setup hooks
global $wgHooks;
$wgHooks["UserLoadFromSession"][] = "casLogin";
$wgHooks["UserLogoutComplete"][] = "casLogout";
$wgHooks["GetPreferences"][] = "casPrefs";
 
// Login
function casLogin($user, &$result) {
		error_log("casLogin(...);\n", 3, "/var/tmp/mes-erreurs.log");
		error_log($_REQUEST["title"], 3, "/var/tmp/mes-erreurs.log");
        global $CASAuth;
        global $IP, $wgLanguageCode, $wgRequest, $wgOut;
 
        if (isset($_REQUEST["title"])) {
 
                $lg = Language::factory($wgLanguageCode);
 
                if ($_REQUEST["title"] == $lg->specialPage("Userlogin")) {      
                        // Initialize the session
                        session_start();
 
                        // Setup for a web request
                        require_once("$IP/includes/WebStart.php");
 
                        // Load phpCAS
                        //require_once($CASAuth["phpCAS"]."/CAS.php");
                        //phpCAS::client($CASAuth["Version"], $CASAuth["Server"], $CASAuth["Port"], $CASAuth["Url"], false);
                        //phpCAS::setNoCasServerValidation();
                        //phpCAS::forceAuthentication(); //Will redirect to CAS server if not logged in
 
                        // Get username
                        //$username = phpCAS::getUser();
						
						$website_cookie = ".openfoodfacts.org";
						$name_cookie = "session";
						$cookie = $_COOKIE; // tu peux récupérer le cookie en PHP

						/* 		user_session
							&	[session_id]
							& 	user_id
							&	stephane 			*/
						$valeur_cookie = $cookie[$name_cookie];
						
						//Parser user_session&4414725571&user_id&manu1400
						$tab_valeurs = split("&", $valeur_cookie); //Pas de limite
						$numero_session = $tab_valeurs[1]; //numéro de la session
						$username = $tab_valeurs[3]; //nom de l'utilisateur
						/* POST */
						$r = new HttpRequest('http://fr.openfoodfacts.org/cgi/sso.pl', HttpRequest::METH_POST);
						$r->addPostFields(array('user_id' => $username, 'user_session' => $numero_session));
						try {
							$retour = $r->send()->getBody();
							error_log($retour, 3, "/var/tmp/mes-erreurs.log");
							$obj = json_decode($retour);
							
							// Get MediaWiki user
							$u = User::newFromName($username);

							if ($u == false) {


$targetPage = "Log in";
$target = Title::newFromText( $targetPage );
	
	                if ( $target->isKnown() ) {
	                        $wgOut->redirect( $target->getFullUrl() );
	                }

							}
							else {
	 
							// Create a new account if the user does not exists... in MediaWiki !
							if ($u->getID() == 0 && $CASAuth["CreateAccounts"]) {
									// Create the user
									$u->addToDatabase();
									$u->setRealName($obj->{'name'});
									$u->setEmail($obj->{'email'}); //$username."@".$CASAuth["EmailDomain"]
									$u->setPassword( md5($username.$CASAuth["PwdSecret"]) ); //PwdSecret is used to salt the username, which is then used to create an md5 hash which becomes the password
									$u->setToken();
									$u->saveSettings();
	 
									// Update user count
									$ssUpdate = new SiteStatsUpdate(0,0,0,0,1);
									$ssUpdate->doUpdate();
							}
	 
							// Login successful
							if ($CASAuth["RememberMe"]) {
									$u->setOption("rememberpassword", 1);
							}
							$u->setCookies();
							$user = $u;
	 
							// Redirect if a returnto parameter exists
							$returnto = $wgRequest->getVal("returnto");
							if ($returnto) {
									$target = Title::newFromText($returnto);
									if ($target) {
											$wgOut->redirect($target->getFullUrl()."?action=purge"); //action=purge is used to purge the cache.
									}
							}
						}  # incorrect user name
						} catch (HttpException $ex) {
							echo $ex;
						}

                }
                else if ($_REQUEST["title"] == $lg->specialPage("Userlogout")) {
                        // Logout
                        $user->logout();
                }
        }
 
        // Back to MediaWiki home after login
        return true;
}
 
// Logout
function casLogout() {
        global $CASAuth;
        global $wgUser, $wgRequest;
 
        // Logout from MediaWiki
        $wgUser->doLogout();
 
        // Get returnto value
        $returnto = $wgRequest->getVal("returnto");
        if ($returnto) {
                $target = Title::newFromText($returnto);
                if ($target) {
                        $redirecturl = $target->getFullUrl();
                }
        }
 
        // Logout from CAS (will redirect user to CAS server)
        //require_once($CASAuth["phpCAS"]."/CAS.php");
        //phpCAS::client($CASAuth["Version"], $CASAuth["Server"], $CASAuth["Port"], $CASAuth["Url"], false);
        //if (isset($redirecturl)) {
        //        phpCAS::logoutWithRedirectService($redirecturl);
        //}
        //else {
        //        phpCAS::logout();
        //}
 
        return true; // We won't get here
}
 
// Remove reset password link and remember password checkbox from preferences page
function casPrefs($user, &$preferences) {
        unset($preferences["password"]);
        unset($preferences["rememberpassword"]);
        return true;
}
