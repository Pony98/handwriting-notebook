import json
import subprocess
import sys
import urllib.request
import urllib.error
import webbrowser

GIT_EXE = r"C:\src\flutter\bin\mingit\cmd\git.exe"
GITHUB_USER = "Pony98"
REPO_NAME = "handwriting-notebook"


def create_repo_and_push(token: str) -> None:
    token = token.strip()
    if not token:
        print("Error: Empty token provided.")
        sys.exit(1)

    # 1. Create repository via GitHub REST API
    print(f"1. Creating GitHub repository {GITHUB_USER}/{REPO_NAME}...")
    url = "https://api.github.com/user/repos"
    data = json.dumps({
        "name": REPO_NAME,
        "description": "Handwriting Note-taking App in Flutter with Split-Screen Zoom Mode",
        "private": False,
        "auto_init": False,
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "User-Agent": "HandwritingNotebook-Deployer",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req) as resp:
            print(f"   Repository created successfully (HTTP {resp.status})!")
    except urllib.error.HTTPError as e:
        if e.code == 422:
            print("   Repository already exists on GitHub, proceeding to push...")
        else:
            err_body = e.read().decode("utf-8", errors="ignore")
            print(f"   GitHub API Error ({e.code}): {err_body}")
            sys.exit(1)

    # 2. Push code to GitHub
    print("2. Pushing code to GitHub...")
    auth_remote = f"https://{GITHUB_USER}:{token}@github.com/{GITHUB_USER}/{REPO_NAME}.git"
    clean_remote = f"https://github.com/{GITHUB_USER}/{REPO_NAME}.git"

    subprocess.run([GIT_EXE, "remote", "set-url", "origin", auth_remote], check=True)
    try:
        subprocess.run([GIT_EXE, "push", "-u", "origin", "main", "--force"], check=True)
    finally:
        # Always reset remote URL to clean URL so token is not left in .git/config
        subprocess.run([GIT_EXE, "remote", "set-url", "origin", clean_remote], check=False)

    print("\nSUCCESS! Code pushed and GitHub Actions APK build started!")
    actions_url = f"https://github.com/{GITHUB_USER}/{REPO_NAME}/actions"
    releases_url = f"https://github.com/{GITHUB_USER}/{REPO_NAME}/releases"
    print(f"Actions URL : {actions_url}")
    print(f"Releases URL: {releases_url}")
    webbrowser.open(actions_url)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        create_repo_and_push(sys.argv[1])
    else:
        token_url = "https://github.com/settings/tokens/new?description=HandwritingNotebook-APK&scopes=repo,workflow"
        print("Opening GitHub Token page in your browser...")
        webbrowser.open(token_url)
        user_token = input("Paste your GitHub Personal Access Token (ghp_...) here and press Enter: ")
        create_repo_and_push(user_token)
