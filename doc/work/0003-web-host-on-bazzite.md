# 0003: The web host on bazzite

Status: todo (2026-10-18)

Goal: `tools/install_web_build.sh` builds every demo of a commit (HEAD or the argument) into `bin/web/builds/<commit>/` and switches `bin/web/current`, two builds kept as the play build install of Mine oh Belowed keeps them; an index page at the root lists the demos with the installed commit; a systemd user service serves `bin/web/current` over plain http on the LAN, so the phone and the laptop open `http://bazzite:<port>/`. `doc/build.md` names the port and the service.

Verify:
- `tools/install_web_build.sh` installs HEAD and the index page lists the hello demo with its commit.
- The phone and the laptop open the index and the hello page over the LAN (the user).
