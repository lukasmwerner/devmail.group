local docker = require "docker"
local tool = require "tool"
local http = require "http"
local time = require "time"

print("[SETUP] Pulling latest image")
docker.pull "registry.hafen.run/devmail.group:latest"

print("[PRE-DEPLOY] Spinning down")
if docker.exists "devmailgroup_old" then
	docker.stop "devmailgroup_old"
	docker.remove "devmailgroup_old"
end
docker.rename("devmailgroup", "devmailgroup_old")
docker.stop "devmailgroup_old"

print("[DEPLOY] Starting container")
docker.run(
	"registry.hafen.run/devmail.group",
	{
		restart = "always",
		name = "devmailgroup",
		ports = {
			"8095:3000",
		},
	}
)

time.sleep(5 * time.duration.second)

print("[HEALTH] Checking site health")
local _, code = http.get "https://devmail.group"

if code ~= 200 then
	print("[HEALTH] Got non 200 status code.")
	if tool.confirm "Revert deploy?" then
		print("Reverting...")
		docker.stop "devmailgroup"
		docker.remove "devmailgroup"
		docker.rename("devmailgroup_old", "devmailgroup")
		docker.start "devmailgroup"
		print("Done.")
	else
		docker.remove "devmailgroup_old"
	end
else
	print("[HEALTH] Health check passed. Removing old container.")
	docker.remove "devmailgroup_old"
end
