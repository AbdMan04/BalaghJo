# Test Evidence — Chapter 5

This folder contains the manual test execution evidence for Chapter 5
of the GP1 report. Each screenshot is named with its corresponding test
case ID (TC-01 through TC-07) and is linked from the 5.2 sample test
cases table.

## File index

| Test Case | Evidence file | Description |
|---|---|---|
| TC-01 | `tc-01-postman.png` | Postman 201 response for email registration |
| TC-01 | `tc-01-console.png` | Backend terminal showing the simulated 6-digit code |
| TC-02 | `tc-02-postman.png` | Postman 201 response for phone registration |
| TC-02 | `tc-02-console.png` | Backend terminal showing the simulated 6-digit code |
| TC-03 | `tc-03-postman.png` | 200 OK on verify with the correct code; `isVerified: true` |
| TC-04 | `tc-04-postman.png` | 401 Unauthorized on verify with code `000000` |
| TC-05 | `tc-05-postman.png` | 200 OK on login with valid credentials |
| TC-06 | `tc-06-postman.png` | 401 Unauthorized on login with wrong password |
| TC-07 | `tc-07-postman.png` | 201 Created for submit report; `reportId: "RPT-2418"` |

## Test environment

- Backend: Node.js 20 + Express 4 + Mongoose 8 against MongoDB Atlas
- Frontend: Flutter 3.x on a physical Android device
- API testing: Postman v11 with the backend running on `http://localhost:4000`
- Verification: simulated delivery — codes are printed to the backend
  console (Chapter 4, section 4.1)

All 7 test cases passed. See section 5.2 of the GP1 report for the full
input / expected output / actual output table.
