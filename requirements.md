in this project, I want to have it check that it can reach the agent it is connected to. if it returns 503 then it should somehow suggest that the Desktop clien
t needs to have the tunnel turned on. If in the api calls there is some error to do with a missing field, thene it should suggest that the desktop app needs to be updated to be compatible (there is a sheet which shows how to install it - can probably reuse that button so they can install it fresh)

Shouldn't spread the code all over, there is an api class which knows about these errors.


📅 DEBUG: Loaded sessions by date:
⚠️ No sessions preloaded - server may not be connected or no sessions exist
⏱️ [PERF] fetchInsights() completed in 0.90s
🚨 Failed to fetch insights: 503 - Agent not connected


🚨 Connection Test Failed - HTTP 503: Agent not connected
⏱️ [PERF] fetchInsights() completed in 0.90s
🚨 Failed to fetch insights: 503 - Agent not connected
⚠️ WelcomeCard: Failed to fetch token count - showing 0
⏱️ [PERF] fetchSessions() completed in 0.90s
🚨 Sessions fetch failed - HTTP 503: Agent not connected

503 means that desktop app needs to have tunnel enabled.

errors to do with fields from the api code means it needs to be updated.

This applies when it is not connected to the demo/trial mode.

To build, checkout AGENTS.md for how to validate in xcode (it should build)
