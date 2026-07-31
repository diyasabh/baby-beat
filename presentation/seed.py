#!/usr/bin/env python3
"""Seed Baby Beat's App Group defaults in the simulator so each presentation
flow can be captured from a known state. Writes the same JSON shapes Swift's
JSONEncoder produces, so the app decodes them unchanged.

    python3 seed.py parent_alert

States: caregiver_asked, caregiver_calm_sent, caregiver_alert_sent,
        parent_calm, parent_alert, parent_waiting, fresh
"""
import json, plistlib, subprocess, sys, uuid, datetime, os

DEVICE = os.environ.get("BB_DEVICE", "66B2D002-384A-48D2-ABF2-96F0DA976BAF")
BUNDLE = "com.diyasabh.babybeat"
GROUP = "group.com.diyasabh.babybeat"
REF_EPOCH = 978307200.0  # 2001-01-01 UTC, Swift's Date reference

PLACE = "little clouds daycare"
CARER = "miss rosie"


def swift_date(dt):
    return dt.timestamp() - REF_EPOCH


def uid():
    return str(uuid.uuid4()).upper()


def reading(bpm, when):
    return {"id": uid(), "bpm": bpm, "date": swift_date(when),
            "caregiver": CARER, "place": PLACE}


def day_history():
    """The same believable daycare day the app seeds itself."""
    now = datetime.datetime.now()
    out = []
    for h, m, bpm in [(8, 45, 138), (10, 10, 126), (12, 30, 96), (15, 5, 152)]:
        when = now.replace(hour=h, minute=m, second=0, microsecond=0)
        if when <= now:
            out.append(reading(bpm, when))
    return out


def ask(minutes_ago, answered=False):
    when = datetime.datetime.now() - datetime.timedelta(minutes=minutes_ago)
    a = {"id": uid(), "date": swift_date(when), "fromParent": "mom", "babyName": "baby"}
    if answered:
        a["answeredAt"] = swift_date(datetime.datetime.now())
    return a


def build(state):
    """Returns (profile, readings, providers, requests) for a named state."""
    provider = [{"id": uid(), "name": CARER, "place": PLACE}]
    parent = {"role": "parent", "name": "mom", "place": PLACE, "babyName": "baby"}
    caregiver = {"role": "caregiver", "name": CARER, "place": PLACE, "babyName": "baby"}

    hist = day_history()
    just_now = datetime.datetime.now() - datetime.timedelta(seconds=40)
    calm = reading(113, just_now)
    alarm = reading(195, just_now)

    if state == "fresh":
        return None, [], [], []
    if state == "caregiver_asked":
        # A parent is waiting. The reason a caregiver opens the app at all.
        return caregiver, hist, [], [ask(8)]
    if state == "caregiver_calm_sent":
        return caregiver, hist + [calm], [], [ask(9, answered=True)]
    if state == "caregiver_alert_sent":
        return caregiver, hist + [alarm], [], [ask(9, answered=True)]
    if state == "parent_calm":
        return parent, hist + [calm], provider, []
    if state == "parent_alert":
        return parent, hist + [alarm], provider, []
    if state == "parent_waiting":
        return parent, hist + [calm], provider, [ask(2)]
    raise SystemExit("unknown state: " + state)


def group_plist():
    out = subprocess.run(["xcrun", "simctl", "get_app_container", DEVICE, BUNDLE, GROUP],
                         capture_output=True, text=True, check=True).stdout.strip()
    return os.path.join(out, "Library", "Preferences", GROUP + ".plist")


def main():
    state = sys.argv[1]
    profile, readings, providers, requests = build(state)
    path = group_plist()
    os.makedirs(os.path.dirname(path), exist_ok=True)

    # plistlib rather than plutil: these keys contain dots, which plutil would
    # read as key paths.
    prefs = {}
    if os.path.exists(path):
        with open(path, "rb") as f:
            try:
                prefs = plistlib.load(f)
            except Exception:
                prefs = {}

    if profile is None:
        # Fresh install look: drop everything so onboarding runs again.
        for key in ("beat.profile", "beat.readings", "beat.providers", "beat.requests",
                    "beat.seeded", "beat.seededAsk", "beat.reminders"):
            prefs.pop(key, None)
    else:
        # Swift stores each of these as JSON encoded Data.
        prefs["beat.profile"] = json.dumps(profile).encode()
        prefs["beat.readings"] = json.dumps(readings).encode()
        prefs["beat.providers"] = json.dumps(providers).encode()
        prefs["beat.requests"] = json.dumps(requests).encode()
        # Block the app's own first run seeding so it cannot overwrite this.
        prefs["beat.seeded"] = True
        prefs["beat.seededAsk"] = True
        prefs["beat.reminders"] = True

    with open(path, "wb") as f:
        plistlib.dump(prefs, f, fmt=plistlib.FMT_BINARY)

    # cfprefsd caches this file; without a restart the app reads stale values.
    subprocess.run(["xcrun", "simctl", "spawn", DEVICE, "killall", "-9", "cfprefsd"],
                   capture_output=True)
    latest = readings[-1]["bpm"] if readings else "none"
    print("seeded {}  latest={} bpm  requests={}".format(state, latest, len(requests)))


if __name__ == "__main__":
    main()
