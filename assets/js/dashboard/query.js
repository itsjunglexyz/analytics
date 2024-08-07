import { parseSearch, stringifySearch } from './util/url'
import { nowForSite, formatISO, shiftDays, shiftMonths, isBefore, parseUTCDate, isAfter } from './util/date'
import { getFiltersByKeyPrefix, parseLegacyFilter, parseLegacyPropsFilter } from './util/filters'

export function addFilter(query, filter) {
  return { ...query, filters: [...query.filters, filter] }
}

export function navigateToQuery(navigate, { period }, newPartialSearchRecord) {
  // if we update any data that we store in localstorage, make sure going back in history will
  // revert them
  if (newPartialSearchRecord.period && newPartialSearchRecord.period !== period) {
    navigate({ search: (search) => ({ ...search, period: period }), replace: true })
  }

  // then push the new query to the history
  navigate({ search: (search) => ({ ...search, ...newPartialSearchRecord }) })
}

const LEGACY_URL_PARAMETERS = {
  'goal': null,
  'source': null,
  'utm_medium': null,
  'utm_source': null,
  'utm_campaign': null,
  'utm_content': null,
  'utm_term': null,
  'referrer': null,
  'screen': null,
  'browser': null,
  'browser_version': null,
  'os': null,
  'os_version': null,
  'country': 'country_labels',
  'region': 'region_labels',
  'city': 'city_labels',
  'page': null,
  'hostname': null,
  'entry_page': null,
  'exit_page': null,
}

// Called once when dashboard is loaded load. Checks whether old filter style is used and if so,
// updates the filters and updates location
export function filtersBackwardsCompatibilityRedirect(windowLocation, windowHistory) {
  const searchRecord = parseSearch(windowLocation.search)
  const getValue = (k) => searchRecord[k];

  // New filters are used - no need to do anything
  if (getValue("filters")) {
    return
  }

  const changedSearchRecordEntries = [];
  let filters = []
  let labels = {}

  for (const [key, value] of Object.entries(searchRecord)) {
    if (LEGACY_URL_PARAMETERS.hasOwnProperty(key)) {
      const filter = parseLegacyFilter(key, value)
      filters.push(filter)
      const labelsKey = LEGACY_URL_PARAMETERS[key]
      if (labelsKey && getValue(labelsKey)) {
        const clauses = filter[2]
        const labelsValues = getValue(labelsKey).split('|').filter(label => !!label)
        const newLabels = Object.fromEntries(clauses.map((clause, index) => [clause, labelsValues[index]]))

        labels = Object.assign(labels, newLabels)
      }
    } else {
      changedSearchRecordEntries.push([key, value])
    }
  }

  if (getValue('props')) {
    filters.push(...parseLegacyPropsFilter(getValue('props')))
  }

  if (filters.length > 0) {
    changedSearchRecordEntries.push(['filters', filters], ['labels', labels])
    windowHistory.pushState({}, null, `${windowLocation.pathname}${stringifySearch(Object.fromEntries(changedSearchRecordEntries))}`)
  }
}

// Returns a boolean indicating whether the given query includes a
// non-empty goal filterset containing a single, or multiple revenue
// goals with the same currency. Used to decide whether to render
// revenue metrics in a dashboard report or not.
export function revenueAvailable(query, site) {
  const revenueGoalsInFilter = site.revenueGoals.filter((rg) => {
    const goalFilters = getFiltersByKeyPrefix(query, "goal")

    return goalFilters.some(([_op, _key, clauses]) => {
      return clauses.includes(rg.event_name)
    })
  })

  const singleCurrency = revenueGoalsInFilter.every((rg) => {
    return rg.currency === revenueGoalsInFilter[0].currency
  })

  return revenueGoalsInFilter.length > 0 && singleCurrency
}

const clearedDateSearch = {
  period: null,
  from: null,
  to: null,
  date: null,
  keybindHint: null,
  calendar: null,
}

export function isDateOnOrAfterStatsStartDate({ site, date, period }) {
  return !isBefore(parseUTCDate(date), parseUTCDate(site.statsBegin), period)
}

export function isDateBeforeOrOnCurrentDate({ site, date, period }) {
  const currentDate = nowForSite(site)
  return !isAfter(parseUTCDate(date), currentDate, period)
}


export function getDateForShiftedPeriod({ site, query, direction }) {
  const isWithinRangeByDirection = {
    '-1': isDateOnOrAfterStatsStartDate,
    '1': isDateBeforeOrOnCurrentDate
  }
  const shiftByPeriod = {
    day: { shift: shiftDays, amount: 1 },
    month: { shift: shiftMonths, amount: 1 },
    year: { shift: shiftMonths, amount: 12 }
  }
  const { shift, amount } = shiftByPeriod[query.period] ?? {};
  if (shift) {
    const date = shift(query.date, direction * amount);
    if (isWithinRangeByDirection[direction]({ site, date, period: query.period })) {
      return date;
    }
  }
  return null
}

export function setQueryPeriodAndDate({ period, date, keybindHint } = { date: null, keybindHint: null }) {
  return function (search) {
    return ({
      ...search,
      ...clearedDateSearch,
      period,
      date,
      keybindHint
    })
  }
};

export function shiftQueryPeriod({ site, query, direction, keybindHint }) {
  const date = getDateForShiftedPeriod({ site, query, direction })
  if (date !== null) {
    return setQueryPeriodAndDate({ period: query.period, date: formatISO(date), keybindHint })
  }
  return (search) => search
};
