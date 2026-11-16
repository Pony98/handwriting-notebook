import json
import sys
import time
import urllib.parse
import urllib.request
import webbrowser
from auto_deploy_github import create_repo_and_push

# Official GitHub CLI OAuth Client ID for Device Flow
CLIENT_ID = "178c6fc778ccc68e1d6a"


def main() -> None:
    req_data = urllib.parse.urlencode({
        "client_id": CLIENT_ID,
        "scope": "repo workflow",
    }).encode("utf-8")

    req = urllib.request.Request(
        "https://github.com/login/device/code",
        data=req_data,
        headers={"Accept": "application/json"},
        method="POST",
    )

    with urllib.request.urlopen(req) as resp:
        device_info = json.loads(resp.read().decode("utf-8"))

    device_code = device_info["device_code"]
    user_code = device_info["user_code"]
    verification_uri = device_info["verification_uri"]
    interval = int(device_info.get("interval", 5)) + 1
    expires_in = int(device_info.get("expires_in", 900))

    print("==========================================", flush=True)
    print(f"GITHUB_USER_CODE: {user_code}", flush=True)
    print(f"VERIFICATION_URI: {verification_uri}", flush=True)
    print("==========================================", flush=True)

    try:
        webbrowser.open(verification_uri)
    except Exception:
        pass

    deadline = time.time() + expires_in
    while time.time() < deadline:
        time.sleep(interval)
        poll_data = urllib.parse.urlencode({
            "client_id": CLIENT_ID,
            "device_code": device_code,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        }).encode("utf-8")

        poll_req = urllib.request.Request(
            "https://github.com/login/oauth/access_token",
            data=poll_data,
            headers={"Accept": "application/json"},
            method="POST",
        )

        with urllib.request.urlopen(poll_req) as poll_resp:
            token_info = json.loads(poll_resp.read().decode("utf-8"))

        if "access_token" in token_info:
            print("Authorization received! Deploying repository and starting APK build...", flush=True)
            create_repo_and_push(token_info["access_token"])
            return

        error = token_info.get("error")
        if error == "authorization_pending":
            continue
        elif error == "slow_down":
            interval += 5
            continue
        else:
            print(f"Device flow ended with error: {error}", flush=True)
            sys.exit(1)

    print("Timed out waiting for GitHub device authorization.", flush=True)
    sys.exit(1)


if __name__ == "__main__":
    main()
