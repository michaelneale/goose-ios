in this project, I want to have it check that it can reach the agent it is connected to. if it returns 503 then it should somehow suggest that the Desktop clien
t needs to have the tunnel turned on. If in the api calls there is some error to do with a missing field, thene it should suggest that the desktop app needs to be updated to be compatible (there is a sheet which shows how to install it - can probably reuse that button so they can install it fresh)

Shouldn't spread the code all over, there is an api class which knows about these errors.

Define a shared global state object (e.g. AppNoticeCenter with @Published var activeNotice: AppNotice?) and inject it at the top level of your app (in @main inside the WindowGroup via .environmentObject(...)), then attach one .overlay / .sheet / .fullScreenCover to that root view that reads activeNotice; whenever any part of the app needs to tell the user something important about network / sync / whatever (e.g. “Sync paused, tap to retry”), it just sets noticeCenter.activeNotice = .syncPaused, and because the overlay is defined once at the root, that message will appear globally above whatever screen the user is currently on, with zero per-screen wiring.


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


requirements:
503 means that desktop app needs to have tunnel enabled.
errors to do with fields from the api code means it needs to be updated.

This applies when it is not connected to the demo/trial mode only. when in demo mode no need for this.

To build, checkout AGENTS.md for how to validate in xcode (it should build)
