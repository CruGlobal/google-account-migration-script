## requirements

You must have a modern (2.1+) version of ruby and the chromedriver installed on your path (https://github.com/SeleniumHQ/selenium/wiki/ChromeDriver)

You must also copy the `config.json` file (which you can get from Mark K. or Shelby B.) into the root of this project.

## install

`bundle install`

## setup and permissions
Before you run the script, you will need to create key_login.rb, config.json, and config.yml. Then copy the respective example files and follow the configuration/setup as follows:

### key_login.rb

You will need to add your okta/key username and password to this file in the respective placeholders.

### config.json

To enable access to google sheets, you will need to include the `cliend_id` and the `client_secret` from the google cloud services. If for some reason Mark K or Shelby B is unavailable to give you these you will need access to [google cloud services](https://console.cloud.google.com/). Someone will need to add you to the "automated google migration" project. From there you can navigate to
> api's and services -> credentials -> click on "google drive ruby" (under OAuth 2.0 Client IDs)

You will also need to remove the refresh_token. The google_drive gem will autofill it, but you must remove the refresh_token for this to happen.

### config.yml

This outlines how the script is going to interact and iterate over the data in the google sheet of interest. 
- the spreadsheet key will come from the url
- start_row_number and end_row_number indicate starting and ending rows
- to get an okta token you will need to reach out to jason buckner and ask for okta admin priveleges. Once acquired, go to [okta admin api token page](https://signon-admin.okta.com/admin/access/api/tokens) and just create a token with your name. Then copy/paste as the value for okta_token.

## running

`ruby auto.rb`

The first time you run this you'll receive some prompts to fill in a key. Follow the instructions.

This will run one dry run. Once you are comfortable, you can turn off dry-run inside the `auto.rb` file.

## troubleshooting

If you have issues remove the refresh_token from config.json and try running again. The refresh_token expires about every 6 months and will need to be removed so the gem can replace it.
