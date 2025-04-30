# Samba 4 Manager - Debian Scripts

[![Author](https://img.shields.io/badge/Author-Rafael%20Schuh-blue.svg)](https://github.com/rafaelhschuh)
[![GitHub stars](https://img.shields.io/github/stars/rafaelhschuh/samba-4-scipts.svg?style=social&label=Star&maxAge=2592000)](https://github.com/rafaelhschuh/samba-4-scipts/stargazers/)

---

## Overview

Welcome to the **Samba 4 Manager** script collection! This set of scripts provides a user-friendly, terminal-based interface (`dialog`) to simplify the installation, configuration, and management of Samba 4 on Debian-based systems. Whether you need an Active Directory Domain Controller, a standalone file server, or a domain member, these scripts aim to streamline the process.

The scripts support multiple languages (English and Brazilian Portuguese) and guide you through the necessary steps with clear prompts and feedback.

## Features

*   **Multi-language Support**: Choose between English (US) and Portuguese (Brazil) at startup.
*   **User-Friendly Interface**: Utilizes `dialog` for a clean, menu-driven terminal experience.
*   **Samba Installation/Update**: Checks for existing Samba installations and offers either a full installation or an update.
*   **Versatile Samba Roles**:
    *   Setup Samba 4 as an **Active Directory Domain Controller**.
    *   Configure Samba 4 as a **Standalone File Server**.
    *   Join an existing domain as a **Domain Member**.
*   **Dependency Management**: Automatically checks and installs required dependencies for Samba and the manager scripts.
*   **Self-Update**: Option to check for and install updates for the Samba Manager scripts directly from GitHub.
*   **Group & Permission Management**: 
    *   Define a global tag for groups.
    *   Create new groups with the defined tag (`groupname-smb@tag`).
    *   Modify group permissions on shared folders using ACLs.
    *   List groups (with tag) and their members.
*   **User Management**: 
    *   Define a global tag for users (uses the same tag as groups).
    *   Add new users with the defined tag (`username@tag`).
    *   Associate new users with existing tagged groups.
    *   List users (with tag).
*   **Critical Area**: Safely remove Samba 4, the Samba Manager scripts, or both.
*   **Automated Installation**: A simple one-line command to download and install the manager.

## Automated Installation

To quickly install or update the Samba 4 Manager on your Debian system, you can use the automated installation script directly from GitHub. This script will download the necessary files to a hidden directory (`~/.samba-scripts`) and create a convenient launcher command (`samba-script`) in `/usr/local/bin`.

**Run the following command as root:**

```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/rafaelhschuh/samba-4-scipts-test/main/install.sh)"
```

*Or using curl:*

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/rafaelhschuh/samba-4-scipts-test/main/install.sh)"
```

This command downloads and executes the installer script, which handles the rest.

## Usage

After a successful installation using the automated script above, you can run the Samba 4 Manager from anywhere in your terminal using the following command:

```bash
sudo samba-script
```

1.  You will be prompted to select your preferred language (English or Portuguese).
2.  The main menu will appear, allowing you to choose between:
    *   **Install/Update Samba 4**: Checks if Samba is installed. If not, guides you through setting up Samba as a DC, File Server, or Domain Member. If installed, offers to update Samba packages.
    *   **Update Samba Manager**: Checks for and installs updates for these manager scripts from GitHub.
    *   **Manage Groups & Permissions**: Define a global tag, create tagged groups (`group-smb@tag`), manage folder permissions (ACLs) for these groups.
    *   **Manage Users**: Add new tagged users (`user@tag`), associate them with tagged groups, list tagged users.
    *   **Critical Area**: Options to remove Samba 4, the Samba Manager scripts, or both (Use with extreme caution!).
    *   **About**: Displays information about the script.
    *   **Exit**: Closes the manager.

Follow the on-screen instructions provided by the `dialog` interface to complete your desired tasks.

## Documentation

For more detailed instructions on installation and usage, please refer to the complete documentation available in your preferred language:

*   **[English Documentation](./DOCUMENTATION_EN.md)**
*   **[Documentação em Português](./DOCUMENTACAO_PT.md)**

## Requirements

*   Debian-based operating system (Debian 10 Buster or later recommended).
*   Root privileges (`sudo`).
*   Internet connection (for downloading packages and the manager itself).

## Author

*   **Rafael Schuh** - [github.com/rafaelhschuh](https://github.com/rafaelhschuh)

*April 2025*

---

Feel free to contribute, report issues, or suggest improvements on the [GitHub repository](https://github.com/rafaelhschuh/samba-4-scipts)!
# samba-4-scipts-test
