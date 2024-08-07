/* @format */
import { useMemo } from 'react'
import { setQueryPeriodAndDate } from './query'
import { useSiteContext } from './site-context'
import {
  formatISO,
  isSameDate,
  isSameMonth,
  isThisYear,
  lastMonth,
  nowForSite,
  yesterday
} from './util/date'
import { COMPARISON_DISABLED_PERIODS, DEFAULT_COMPARISON_MODE, getStoredComparisonMode, isComparisonEnabled, storeComparisonMode } from './comparison-input'

const getPeriodOptions = ({ name, period, getDate, keyboardKey, isActive }) => {
  const date = getDate ? getDate() : null
  return {
    period,
    date,
    ...(!!keyboardKey && {
      keybind: {
        keyboardKey,
        type: 'keydown'
      }
    }),
    navigation: {
      search: setQueryPeriodAndDate({
        period,
        date: date ? formatISO(date) : null
      }),
      isActive
    },
    button: {
      label: name
    }
  }
}

const getTodayOptions = ({ site }) =>
  getPeriodOptions({
    name: 'Today',
    period: 'day',
    getDate: () => nowForSite(site),
    isActive: ({ query }) =>
      query.period === 'day' && isSameDate(query.date, nowForSite(site)),
    keyboardKey: 'D'
  })

const getYesterdayOptions = ({ site }) =>
  getPeriodOptions({
    name: 'Yesterday',
    period: 'day',
    getDate: () => yesterday(site),
    isActive: ({ query }) =>
      query.period === 'day' && isSameDate(query.date, yesterday(site)),
    keyboardKey: 'E'
  })

const realtimeOptions = getPeriodOptions({
  name: 'Realtime',
  period: 'realtime',
  getDate: null,
  isActive: ({ query }) => query.period === 'realtime',
  keyboardKey: 'R'
})

const last7DaysOptions = getPeriodOptions({
  name: 'Last 7 days',
  period: '7d',
  getDate: null,
  isActive: ({ query }) => query.period === '7d',
  keyboardKey: 'W'
})

const last30DaysOptions = getPeriodOptions({
  name: 'Last 30 days',
  period: '30d',
  getDate: null,
  isActive: ({ query }) => query.period === '30d',
  keyboardKey: 'T'
})

const getMonthToDateOptions = ({ site }) =>
  getPeriodOptions({
    name: 'Month to Date',
    period: 'month',
    getDate: null,
    isActive: ({ query }) =>
      query.period === 'month' && isSameMonth(query.date, nowForSite(site)),
    keyboardKey: 'M'
  })

const getLastMonthOptions = ({ site }) =>
  getPeriodOptions({
    name: 'Last month',
    period: 'month',
    getDate: () => lastMonth(site),
    isActive: ({ query }) =>
      query.period === 'month' && isSameMonth(query.date, lastMonth(site)),
    keyboardKey: null
  })

const getYearToDateOptions = ({ site }) =>
  getPeriodOptions({
    name: 'Year to Date',
    period: 'year',
    getDate: null,
    isActive: ({ query }) =>
      query.period === 'year' && isThisYear(site, query.date),
    keyboardKey: 'Y'
  })

const last12MonthsOptions = getPeriodOptions({
  name: 'Last 12 months',
  period: '12mo',
  getDate: null,
  isActive: ({ query }) => query.period === '12mo',
  keyboardKey: 'L'
})

const allTimeOptions = getPeriodOptions({
  name: 'All time',
  period: 'all',
  getDate: null,
  isActive: ({ query }) => query.period === 'all',
  keyboardKey: 'A'
})

const pickCustomRangeOptions = {
  date: null,
  period: 'custom',
  navigation: {
    search: (search) => ({
      ...search,
      calendar: search.calendar === 'open' ? null : 'open'
    }),
    isActive: ({ query }) => query.period === 'custom'
  },
  keybind: {
    keyboardKey: 'C',
    type: 'keydown'
  },
  button: {
    label: 'Custom Range'
  }
}

export const last6MonthsOptions = getPeriodOptions({
  name: 'Last 6 months',
  period: '6mo',
  getDate: null,
  isActive: ({ query }) => query.period === '6mo',
  keyboardKey: 'S'
})

export const getComparisonSearch = ({ site, query }) => (search) => COMPARISON_DISABLED_PERIODS.includes(query.period) ? ({search}) : ({
  ...search,
  comparison: isComparisonEnabled(query)
    ? 'off'
    : getStoredComparisonMode(site.domain, DEFAULT_COMPARISON_MODE) === 'off' ? storeComparisonMode(site.domain, DEFAULT_COMPARISON_MODE) ?? DEFAULT_COMPARISON_MODE : getStoredComparisonMode(site.domain, DEFAULT_COMPARISON_MODE)
})

export const useSelectableDatePeriodGroups = () => {
  const site = useSiteContext()
  return useMemo(
    () => [
      [
        getTodayOptions({ site }),
        getYesterdayOptions({ site }),
        realtimeOptions
      ],
      [last7DaysOptions, last30DaysOptions],
      [getMonthToDateOptions({ site }), getLastMonthOptions({ site })],
      [getYearToDateOptions({ site }), last12MonthsOptions],
      [allTimeOptions, pickCustomRangeOptions]
    ],
    [site]
  )
}
