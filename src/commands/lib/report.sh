# shellcheck shell=bash
# @file report.sh
# @brief Shared structured-report collector and renderers for read-only checks.

REPORT_RECORDS=()
REPORT_SEPARATOR=$'\t'
CATEGORY_ORDER=(toolchain runtime profile packages)
STATUS_ORDER=(error drift warning ok)

if [[ "${RNFMAC_REPORT_FORMAT:-human}" != "human" ]]; then
  RNF_LOG_LEVEL=60
fi

# @description Append one structured check result to the report buffer.
# @arg $1 string Status: `error`, `drift`, `warning`, or `ok`.
# @arg $2 string Category name.
# @arg $3 string Check identifier.
# @arg $4 string Human-readable result message.
# @set REPORT_RECORDS Appends the encoded result record.
function report_add() {
  local result_status="$1" category="$2" check="$3" message="$4"
  REPORT_RECORDS+=("${result_status}${REPORT_SEPARATOR}${category}${REPORT_SEPARATOR}${check}${REPORT_SEPARATOR}${message}")
  return 0
}

# @description Parse one encoded result into shared fields for report helpers.
# @arg $1 string A tab-separated report record.
# @set REPORT_STATUS Parsed status.
# @set REPORT_CATEGORY Parsed category.
# @set REPORT_CHECK Parsed check identifier.
# @set REPORT_MESSAGE Parsed message.
# @set REPORT_RECORD_GROUP Parsed originating command group.
function _report_parse_record() {
  local record="$1"
  IFS="${REPORT_SEPARATOR}" read -r REPORT_STATUS REPORT_CATEGORY REPORT_CHECK REPORT_MESSAGE REPORT_RECORD_GROUP <<<"${record}"
  return 0
}

# @description Escape a value for use inside a JSON string.
# @arg $1 string Unescaped value.
# @stdout The JSON-escaped value.
function _report_json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\t'/\\t}"
  printf '%s' "${value}"
  return 0
}

# @description Print the worst status currently present in the report buffer.
# @stdout `error`, `drift`, `warning`, or `ok`.
function report_worst() {
  local record
  for record in "${REPORT_RECORDS[@]}"; do
    _report_parse_record "${record}"
    [[ "${REPORT_STATUS}" = "error" ]] && echo "error" && return 0
  done
  for record in "${REPORT_RECORDS[@]}"; do
    _report_parse_record "${record}"
    [[ "${REPORT_STATUS}" = "drift" ]] && echo "drift" && return 0
  done
  for record in "${REPORT_RECORDS[@]}"; do
    _report_parse_record "${record}"
    [[ "${REPORT_STATUS}" = "warning" ]] && echo "warning" && return 0
  done
  echo "ok"
}

# @description Print the report exit code based on its worst status.
# @stdout `0` for healthy or warning-only, `2` for drift, or `1` for error.
function report_exit_code() {
  case "$(report_worst)" in
  error) echo 1 ;;
  drift) echo 2 ;;
  *) echo 0 ;;
  esac
  return 0
}

# @description Render the buffered records as human output, JSONL, or raw records.
# @stdout Human or JSONL output; raw mode writes only to `RNFMAC_REPORT_FILE`.
# @set RNF_LOG_LEVEL Set to 60 for non-human formats to suppress logger output.
function report_render() {
  local format="${RNFMAC_REPORT_FORMAT:-human}"
  local record category result_status count_ok=0 count_warning=0 count_drift=0 count_error=0

  if [[ "${format}" != "human" ]]; then
    export RNF_LOG_LEVEL=60
  fi

  if [[ "${format}" = "raw" ]]; then
    for record in "${REPORT_RECORDS[@]}"; do
      printf '%s%s%s\n' "${record}" "${REPORT_SEPARATOR}" "${REPORT_GROUP}" >>"${RNFMAC_REPORT_FILE}"
    done
    return 0
  fi

  if [[ "${format}" = "json" ]]; then
    for record in "${REPORT_RECORDS[@]}"; do
      _report_parse_record "${record}"
      printf '{"status":"%s","group":"%s","category":"%s","check":"%s","message":"%s"}\n' \
        "$(_report_json_escape "${REPORT_STATUS}")" \
        "$(_report_json_escape "${REPORT_RECORD_GROUP:-${REPORT_GROUP}}")" \
        "$(_report_json_escape "${REPORT_CATEGORY}")" \
        "$(_report_json_escape "${REPORT_CHECK}")" \
        "$(_report_json_escape "${REPORT_MESSAGE}")"
    done
    return 0
  fi

  for record in "${REPORT_RECORDS[@]}"; do
    _report_parse_record "${record}"
    case "${REPORT_STATUS}" in
    ok) count_ok=$((count_ok + 1)) ;;
    warning) count_warning=$((count_warning + 1)) ;;
    drift) count_drift=$((count_drift + 1)) ;;
    error) count_error=$((count_error + 1)) ;;
    *) ;;
    esac
  done

  for category in "${CATEGORY_ORDER[@]}"; do
    local category_present=0
    for record in "${REPORT_RECORDS[@]}"; do
      _report_parse_record "${record}"
      [[ "${REPORT_CATEGORY}" = "${category}" ]] && category_present=1 && break
    done
    [[ "${category_present}" -eq 0 ]] && continue
    log_info "${category}"

    for result_status in "${STATUS_ORDER[@]}"; do
      [[ "${result_status}" = "ok" ]] && [[ "${RNFMAC_REPORT_ALL:-0}" != "1" ]] && continue
      for record in "${REPORT_RECORDS[@]}"; do
        _report_parse_record "${record}"
        [[ "${REPORT_CATEGORY}" = "${category}" ]] || continue
        [[ "${REPORT_STATUS}" = "${result_status}" ]] || continue
        case "${result_status}" in
        error) log_error "${REPORT_MESSAGE}" ;;
        drift | warning) log_warning "${REPORT_MESSAGE}" ;;
        ok) log_success "${REPORT_MESSAGE}" ;;
        *) ;;
        esac
      done
    done
  done

  log_info "${count_ok} ok, ${count_warning} warning, ${count_drift} drift, ${count_error} error"
}
