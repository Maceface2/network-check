#!/bin/bash
# network-check — quick network visibility diagnostic
# Run on the laptop while on the company network (or with VPN on).
# Shows whether the company can see your traffic.

set -u

SEP() { echo; echo "── $1"; echo; }

SEP "1. Forward proxy"
echo "Checking HTTP_PROXY / HTTPS_PROXY env vars:"
proxy_found=0
for v in HTTP_PROXY HTTPS_PROXY http_proxy https_proxy; do
  val="${!v:-}"
  if [ -n "$val" ]; then
    echo "  $v = $val"
    proxy_found=1
  fi
done
if [ "$proxy_found" -eq 0 ]; then
  echo "  (none set — traffic goes direct)"
else
  echo "  => A corporate proxy is in the path; IT can log every hostname."
fi

SEP "2. TLS termination"
echo "Fetching cert details for https://www.google.com:"
curl -sv https://www.google.com -o /dev/null 2>&1 | grep -E "SSL connection established|subject=|issuer="
echo ""
issuer_line=$(curl -sv https://www.google.com -o /dev/null 2>&1 | grep -oP 'issuer=\K[^,]+')
if echo "$issuer_line" | grep -qiE "digi|lets encrypt|google trust|globalsign|sectigo"; then
  echo "  Public CA issuer found => no TLS termination. Traffic payload is unreadable to IT."
elif [ -n "$issuer_line" ]; then
  echo "  Non-standard issuer: $issuer_line"
  echo "  => TLS termination is likely ON (Zscaler/Fortinet/PaloAlto/company-CA)."
else
  echo "  Could not retrieve issuer — check connectivity or run manually."
fi

SEP "3. Endpoint agent"
echo "Scanning for common EDR/MDM agents:"
agents=$(ps aux | grep -iE "crowdstrike|sentinel|carbon|kaseya|falcon|defender|mdm|jamf" | grep -v grep)
if [ -n "$agents" ]; then
  echo "$agents"
  echo "  => Endpoint agent present. IT can see running processes + disk. Avoid local LLM on this machine."
else
  echo "  (no known agents found)"
  echo "  => No endpoint visibility. Local Ollama would leave only a process + disk footprint, not a network trail."
fi

SEP "4. Default route (VPN on vs off)"
echo "Current default route:"
ip route | head -3
echo ""
echo "To test the VPN effect: run this script twice — once with the VPN"
echo "OFF and once with the VPN ON, then compare the default gateway lines."
echo "If the gateway changes, all your traffic is being routed through the"
echo "corporate network while the VPN is up."

SEP "Summary"
echo "Based on the checks above:"
[ "$proxy_found" -eq 0 ] && echo "  ✓ No forward proxy set"
[ -z "$agents" ] && echo "  ✓ No endpoint agents found"
echo ""
echo "If all three checks come back clean (no proxy, no termination, no agents),"
echo "your traffic is effectively unwatched. If the VPN changes the route,"
echo "re-run this script with the VPN ON to confirm the same result holds."
