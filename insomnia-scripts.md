# Insomnia Scripts for WMFNTK User API

## Script 1: Extract Signup Token from Response

**Use this script in the "2. Signup Verify" request under "Response" → "Scripts" → "Response"**

```javascript
// Extract signup token from response headers and set as global variable
const signupToken = response.headers.get('x-signup-token');
if (signupToken) {
    console.log('Signup token extracted:', signupToken);
    // Set as global variable for use in subsequent requests
    insomnia.setGlobalVariable('signup_token', signupToken);
} else {
    console.log('No signup token found in response headers');
}
```

## Script 2: Extract Authentication Token from Response

**Use this script in the "3. Signup Account" request under "Response" → "Scripts" → "Response"**

```javascript
// Extract authentication token from response headers and set as global variable
const authToken = response.headers.get('x-new-token');
if (authToken) {
    console.log('Authentication token extracted:', authToken);
    // Set as global variable for use in subsequent requests
    insomnia.setGlobalVariable('auth_token', authToken);
} else {
    console.log('No authentication token found in response headers');
}
```

## Script 3: Extract Login Authentication Token

**Use this script in the "Verify" request under "Response" → "Scripts" → "Response"**

```javascript
// Extract authentication token from login verification response
const authToken = response.headers.get('x-new-token');
if (authToken) {
    console.log('Login authentication token extracted:', authToken);
    // Set as global variable for use in subsequent requests
    insomnia.setGlobalVariable('auth_token', authToken);
} else {
    console.log('No authentication token found in response headers');
}
```

## Script 4: Add Authentication Header to Request

**Use this script in any authenticated request under "Request" → "Scripts" → "Request"**

```javascript
// Add authentication header to request if token exists
const authToken = insomnia.getGlobalVariable('auth_token');
if (authToken) {
    console.log('Adding authentication header with token');
    request.headers.add('Authorization', `Bearer ${authToken}`);
} else {
    console.log('No authentication token found, request will be unauthenticated');
}
```

## How to Use These Scripts

### Step 1: Add Response Scripts
1. Open the request in Insomnia
2. Go to the "Scripts" tab
3. In the "Response" section, paste the appropriate script
4. Save the request

### Step 2: Add Request Scripts (for authenticated endpoints)
1. For any endpoint that requires authentication
2. Go to the "Scripts" tab
3. In the "Request" section, paste Script 4
4. Save the request

### Step 3: Test the Flow
1. Run "1. Signup Email" 
2. Run "2. Signup Verify" (Script 1 will extract signup token)
3. Run "3. Signup Account" (Script 2 will extract auth token)
4. Any subsequent authenticated requests will automatically include the auth token

## Environment Variables

Make sure your environment has these variables defined:
- `base_url`: Your API base URL (e.g., `http://localhost:8080`)
- `signup_token`: Will be automatically set by Script 1
- `auth_token`: Will be automatically set by Script 2 or 3

## Troubleshooting

- Check the Insomnia console for script output
- Verify that the response headers contain the expected tokens
- Ensure the environment variables are being set correctly
- If tokens aren't being extracted, check the response status and headers 