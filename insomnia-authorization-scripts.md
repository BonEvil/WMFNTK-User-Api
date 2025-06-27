# Insomnia Authorization Collection - After Response Scripts

## Overview
This document provides instructions for adding the automatic token extraction script to the WMFNTK User API Authorization collection.

## After Response Script
Add the following script to the "After Response" tab of each request in the collection:

```javascript
const header = insomnia.response.headers.find(
    header => header.key === 'x-new-token',
    {},
);

if (header) {
    insomnia.environment.set("auth_token", header.value);
}
```

## Requests That Need the Script
Add this script to the following requests:

1. **Get Profile** (`GET /api/v1/profile`)
2. **Update Profile** (`PUT /api/v1/profile`)
3. **Get Account** (`GET /api/v1/accounts/{accountId}`)
4. **Update Account** (`PUT /api/v1/accounts/{accountId}`)
5. **Get Account Users** (`GET /api/v1/accounts/{accountId}/users`)
6. **Add User to Account** (`POST /api/v1/accounts/{accountId}/users`)
7. **Remove User from Account** (`DELETE /api/v1/accounts/{accountId}/users/{userId}`)

## How to Add the Script
1. Open the request in Insomnia
2. Click on the "After Response" tab
3. Paste the script above
4. Save the request

## Environment Variables
The collection uses the following environment variables:
- `base_url`: The base URL of your API (default: http://localhost:8080)
- `auth_token`: Automatically set by the after-response script
- `account_id`: The account ID for testing (set manually)
- `user_id_to_remove`: The user ID to remove from account (set manually)

## Usage Flow
1. First, use the signup collection to create an account and get an auth token
2. Import this authorization collection
3. Set the `account_id` environment variable to your account ID
4. The auth token will be automatically extracted and used in subsequent requests
5. Test the various authorization endpoints

## Notes
- The script automatically extracts the `x-new-token` header from responses
- The token is stored in the environment variable `auth_token`
- All requests use `Bearer {{ _.auth_token }}` in the Authorization header
- Make sure to set the `account_id` and `user_id_to_remove` variables as needed for testing 