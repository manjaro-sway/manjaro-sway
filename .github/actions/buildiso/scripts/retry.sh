# Retry a network command a few times before believing it.
#
# Four full runs in one session died on transient faults - a 403 from a
# GitLab clone of a public repo, and archlinux.org answering 502 once in
# three requests. Each cost about twenty-five minutes per edition, and
# every one of them would have passed on a second attempt.
#
# Sourced rather than executed: a composite step is its own shell, so each
# step that fetches something sources this first.
#
# shellcheck shell=bash

# Attempts and the first pause between them, both overridable so a caller
# can tighten them; the pause doubles after every failure.
RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"

retry() {
  local attempt=1 delay="$RETRY_DELAY" status=0

  while true; do
    "$@" && return 0
    status=$?

    # A command that fails every attempt is a real fault: report the last
    # exit code rather than swallowing it, so the step still fails.
    if [ "$attempt" -ge "$RETRY_ATTEMPTS" ]; then
      echo "## retry: gave up on '$*' after ${attempt} attempt(s), exit ${status}" >&2
      return "$status"
    fi

    echo "## retry: '$*' failed with exit ${status}, attempt ${attempt}/${RETRY_ATTEMPTS}, retrying in ${delay}s" >&2
    sleep "$delay"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}
