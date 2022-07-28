# Developing with Ory

Here is how to develop with Ory


**Current branch is OryAuth-get-cookies**

All Ory configuration files are in the Ory folder

- kratosauth.yml is the docker configuration with kratos
- kratos.yml is used to configure kratos
- identity.schema.json is used to configure the identity schema such as requiring username, email, etc. 
- hydraauth.yml and hydra.yml are for configuring hydra


# Ory Kratos
## Start up Ory Kratos container
- Add Ory/kratosauth.yml to COMPOSE_FILE variable in .env file
- Set ORY_ENABLED to 1
- Run Make Dev

## Ory Managed UI 
This is useful for seeing if a current user is signed in and seeing the current users info

http://kratos.openfoodfacts.localhost:4455/welcome is the managed UI

From here you can login, sign up, recover account, verify account, and change account setting. 

## Signing in and Creating an Account

Sign in: Can login by clicking creating an account in OFF then clicking sign in ; Need a button to go to http://kratos.openfoodfacts.localhost:4455/login <br/>
Create an account: Click create an account in OFF which redirects you to http://kratos.openfoodfacts.localhost:4455/registration <br/>

- After completing login and sign up flows you will be redirected to world.openfoodfacts.localhost/cgi/kratos_auth.pl
- kratos_auth.pl retrieves the ory_kratos_session cookie, does a HTTP Get request to http://kratos.openfoodfacts.localhost:4433/sessions/whoami and responds with JSON information of the current user
- The JSON is used to create hash that will create a new sto file if the user does not already have one. <br/>
To see the users sto file run following commands: 
  - launch docker-compose run --rm backend re.pl
  - use ProductOpener::Store qw/:all/;
  - my $user_id= "xxxxx" (<- put user ID)
  - my $user_ref = retrieve("/mnt/podata/users/$user_id.sto")
- The user will then be given a session with the open_user_session() function and be redirected back to openfoodfacts.localhost, you can see the session in sto file with above commands
- **OFF still does not display that the user is signed in right after being signed in, refresh page and you'll see you're signed in**

## Logging Out
Click logout in OFF, taking you to http://world.openfoodfacts.localhost/cgi/kratos_logout.pl

- kratos_logout.pl will do a get request to http://kratos.openfoodfacts.localhost:4433/self-service/logout/browser getting a logout url for kratos
- Unset OFF cookie
- Redirecting to given logout url
- Kratos knows where to go after redirecting from logout url as this is configured in kratos.yml

## Account Settings
To change the account settings click change account parameters in OFF which will redirect to http://kratos.openfoodfacts.localhost:4455/settings

kratos_update_settings.pl will update the users sto file after user has updating settings in kratos

After Updating Settings you can see the users updated sto file with 
  - launch docker-compose run --rm backend re.pl
  - use ProductOpener::Store qw/:all/;
  - my $user_id= "xxxxx" (<- put user ID)
  - my $user_ref = retrieve("/mnt/podata/users/$user_id.sto")

## Account recovery and Email verification 
Will configure with the OFF courier see the docs https://www.ory.sh/docs/kratos/guides/account-activation-email-verification

## Common difficulties
If you go to login, sign up, settings, etc. and browser says you are being redirected too many times clear you browser cookies

# Ory Hydra (OAuth and OIDC)
Waiting on [PR](https://github.com/ory/kratos/pull/2549) from Ory that allows native integration with Kratos




