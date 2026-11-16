import json
import os
import sys
import time
import urllib.parse
import urllib.request
import webbrowser
from auto_deploy_github import create_repo_and_push

CLIENT_ID = "178c6fc778ccc68e1d6a"
TOKEN_CACHE = r"C:\Users\ponys\.gemini\antigravity\brain\e0e95c9d-50d8-45f4-bbb0-ecef5aab082b\scratch\.gh_token"


def get_or_request_token() -> str:
    if os.path.exists(TOKEN_CACHE):
        with open(TOKEN_CACHE, "r", encoding="utf-8") as f:
            cached = f.read().strip()
            if cached:
                return cached

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
            token = token_info["access_token"]
            os.makedirs(os.path.dirname(TOKEN_CACHE), exist_ok=True)
            with open(TOKEN_CACHE, "w", encoding="utf-8") as f:
                f.write(token)
            return token

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


def main() -> None:
    token = get_or_request_token()
    print("Authorization ready! Deploying fixed workflow and starting APK build...", flush=True)
    create_repo_and_push(token)


if __name__ == "__main__":
    main()
