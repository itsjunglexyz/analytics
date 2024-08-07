/* @format */
import React, {
  createContext,
  useMemo,
  useEffect,
  useContext,
  useState,
  useCallback
} from 'react'
import { useLocation } from 'react-router'
import { useMountedEffect } from './custom-hooks'
import * as api from './api'
import * as storage from './util/storage'
import { useSiteContext } from './site-context'
import { parseSearch } from './util/url'
import {
  COMPARISON_DISABLED_PERIODS,
  getStoredComparisonMode,
  getStoredMatchDayOfWeek,
  isComparisonEnabled
} from './comparison-input'
import dayjs from 'dayjs'
import { nowForSite, yesterday } from './util/date'

const PERIODS = [
  'realtime',
  'day',
  'month',
  '7d',
  '30d',
  '6mo',
  '12mo',
  'year',
  'all',
  'custom'
]

const queryContextDefaultValue = { query: {}, otherSearch: {}, lastLoadTimestamp: new Date() }

const QueryContext = createContext(queryContextDefaultValue)

export const useQueryContext = () => {
  return useContext(QueryContext)
}

export default function QueryContextProvider({ children }) {
  const location = useLocation()
  const site = useSiteContext()
  const {compare_from, compare_to, comparison, date, filters, from, labels, match_day_of_week, period, to, with_imported, ...otherSearch} = useMemo(
    () => parseSearch(location.search),
    [location.search]
  )

  const query = useMemo(() => {
    let _period = period
    const periodKey = `period__${site.domain}`

    if (PERIODS.includes(_period)) {
      if (_period !== 'custom' && _period !== 'realtime') {
        storage.setItem(periodKey, _period)
      }
    } else if (storage.getItem(periodKey)) {
      _period = storage.getItem(periodKey)
    } else {
      _period = '30d'
    }

    let _comparison =
      comparison ?? getStoredComparisonMode(site.domain, null)
    if (
      COMPARISON_DISABLED_PERIODS.includes(_period) ||
      !isComparisonEnabled(comparison)
    )
    _comparison = null

    let matchDayOfWeek =
      match_day_of_week ??
      getStoredMatchDayOfWeek(site.domain, true)

    return {
      period: _period,
      comparison: _comparison,
      compare_from: compare_from
        ? dayjs.utc(compare_from)
        : undefined,
      compare_to: compare_to
        ? dayjs.utc(compare_to)
        : undefined,
      date: date ? dayjs.utc(date) : nowForSite(site),
      from: from
        ? dayjs.utc(from)
        : _period === 'custom'
          ? yesterday(site)
          : undefined,
      to: to
        ? dayjs.utc(to)
        : _period === 'custom'
          ? nowForSite(site)
          : undefined,
      match_day_of_week: matchDayOfWeek === true,
      with_imported: with_imported ?? true,
      filters: filters || [],
      labels: labels || {}
    }
  }, [compare_from, compare_to, comparison, date, filters, from, labels, match_day_of_week, period, to, with_imported, site])

  const [lastLoadTimestamp, setLastLoadTimestamp] = useState(new Date())
  const updateLastLoadTimestamp = useCallback(() => {
    setLastLoadTimestamp(new Date())
  }, [setLastLoadTimestamp])

  useEffect(() => {
    document.addEventListener('tick', updateLastLoadTimestamp)

    return () => {
      document.removeEventListener('tick', updateLastLoadTimestamp)
    }
  }, [updateLastLoadTimestamp])

  useMountedEffect(() => {
    api.cancelAll()
    updateLastLoadTimestamp()
  }, [])

  return (
    <QueryContext.Provider value={{ query, otherSearch, lastLoadTimestamp }}>
      {children}
    </QueryContext.Provider>
  )
}
