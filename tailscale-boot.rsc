/container/config/set layer-dir=tmpfs tmpdir=tmpfs/pull ram-high=200M
:delay 3s
:if ([:len [/file find where name="containers"]] = 0) do={ /file add name="containers" type=directory }
:if ([:len [/file find where name="containers/tailscale"]] = 0) do={ /file add name="containers/tailscale" type=directory }
:if ([:len [/file find where name="containers/tailscale/state"]] = 0) do={ /file add name="containers/tailscale/state" type=directory }
:if ([:len [/container/mounts find where name="tailscale_state"]] = 0) do={ /container/mounts/add name="tailscale_state" src="containers/tailscale/state" dst="/var/lib/tailscale" }
:if ([:len [/container/find where hostname="mikrotik-tailscale"]] = 0) do={
  :if ([:len [/file find where name="containers/tailscale/tailscale-arm64.tar"]] > 0) do={
    /container/add file=containers/tailscale/tailscale-arm64.tar interface=veth-tailscale envlist=tailscale root-dir=containers/tailscale mounts=tailscale_state start-on-boot=yes hostname=mikrotik-tailscale logging=yes dns=8.8.4.4,8.8.8.8
    :delay 15s
  }
}

# Try starting the container a few times in case extraction takes longer
:local _c [/container/find where hostname="mikrotik-tailscale"]
:for i from=1 to=5 do={
  :do { /container/start $_c } on-error={}
  :delay 5s
  :if ([:len $_c] > 0) do={
    :local _st [/container/get $_c status]
    :if ("$__st" = "running") do={ :break }
  }
}
