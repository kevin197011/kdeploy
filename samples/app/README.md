# Sample Application Directory

This directory demonstrates the directory synchronization feature of Kdeploy.

## Files in this directory

- `index.html` - Sample HTML file
- `app.rb` - Sample Ruby application
- `.gitignore` - Git ignore file (will be synced, but .git directory will be ignored)

## Usage

When you run the sync task:

```bash
kdeploy execute deploy.rb sync_app
```

This directory will be synced to `/var/www/app` on the remote server, with the following files ignored:
- `.git` directory
- `*.log` files
- `*.tmp` files
- `node_modules` directory
- `.env.local` file

