#!/bin/bash

# GitHub Setup Script für ESPP Manager
# Ersetzen Sie YOUR_GITHUB_USERNAME mit Ihrem GitHub Benutzernamen

GITHUB_USERNAME="YOUR_GITHUB_USERNAME"
REPO_NAME="espp-manager"

echo "Setting up GitHub repository..."

# Remote hinzufügen
git remote add origin "https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"

# Branch umbenennen falls nötig
git branch -M main

# Code pushen
echo "Pushing code to GitHub..."
git push -u origin main

echo "Done! Your code is now on GitHub at: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"