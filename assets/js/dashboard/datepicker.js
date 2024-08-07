/* @format */
import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import { Transition } from '@headlessui/react'
import {
  formatDay,
  formatMonthYYYY,
  formatYear,
  isToday,
  isThisMonth,
  isThisYear,
  formatDateRange,
  parseNaiveDate,
  formatISO
} from './util/date'
import {
  shiftQueryPeriod,
  getDateForShiftedPeriod,
  navigateToQuery
} from './query'
import {
  COMPARISON_DISABLED_PERIODS,
  isComparisonEnabled,
} from '../dashboard/comparison-input.js'
import classNames from 'classnames'
import { useQueryContext } from './query-context.js'
import { useSiteContext } from './site-context.js'
import { KeybindHint, NavigateKeybind } from './keybinding.js'
import {
  AppNavigationLink,
  useAppNavigate
} from './navigation/use-app-navigate.js'
import { DateRangeCalendar } from './datepicker-calendar.js'
import {
  getComparisonSearch,
  useSelectableDatePeriodGroups
} from './query-time-periods.js'

export const ArrowKeybind = ({ keyboardKey }) => {
  const site = useSiteContext()
  const { query } = useQueryContext()

  const search = useMemo(
    () =>
      shiftQueryPeriod({
        query,
        site,
        direction: { ArrowLeft: -1, ArrowRight: 1 }[keyboardKey],
        keybindHint: keyboardKey
      }),
    [site, query, keyboardKey]
  )

  return (
    <NavigateKeybind
      type="keydown"
      keyboardKey={keyboardKey}
      navigateProps={{ search }}
    />
  )
}

function ArrowIcon({ direction }) {
  return (
    <svg
      className="feather h-4 w-4"
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {direction === 'left' && <polyline points="15 18 9 12 15 6"></polyline>}
      {direction === 'right' && <polyline points="9 18 15 12 9 6"></polyline>}
    </svg>
  )
}

function DatePickerArrows() {
  const { query } = useQueryContext()
  const site = useSiteContext()
  if (!['year', 'month', 'day'].includes(query.period)) {
    return null
  }

  const canGoBack =
    getDateForShiftedPeriod({ site, query, direction: -1 }) !== null
  const canGoForward =
    getDateForShiftedPeriod({ site, query, direction: 1 }) !== null

  const isComparing = isComparisonEnabled(query.comparison)

  const sharedClass = 'flex items-center px-1 sm:px-2 dark:text-gray-100'
  const enabledClass = 'hover:bg-gray-100 dark:hover:bg-gray-900'
  const disabledClass = 'bg-gray-300 dark:bg-gray-950 cursor-not-allowed'

  const containerClass = classNames(
    'rounded shadow bg-white mr-2 sm:mr-4 cursor-pointer dark:bg-gray-800',
    {
      'hidden md:flex': isComparing,
      flex: !isComparing
    }
  )

  return (
    <div className={containerClass}>
      <AppNavigationLink
        className={classNames(
          sharedClass,
          'rounded-l border-gray-300 dark:border-gray-500',
          { [enabledClass]: canGoBack, [disabledClass]: !canGoBack }
        )}
        disabled={!canGoBack}
        search={shiftQueryPeriod({ site, query, direction: -1 })}
      >
        <ArrowIcon direction="left" />
      </AppNavigationLink>
      <AppNavigationLink
        className={classNames(sharedClass, {
          [enabledClass]: canGoForward,
          [disabledClass]: !canGoForward
        })}
        disabled={!canGoForward}
        search={shiftQueryPeriod({ site, query, direction: 1 })}
      >
        <ArrowIcon direction="right" />
      </AppNavigationLink>
    </div>
  )
}

function DisplayPeriod() {
  const { query } = useQueryContext()
  const site = useSiteContext()
  if (query.period === 'day') {
    if (isToday(site, query.date)) {
      return 'Today'
    }
    return formatDay(query.date)
  }
  if (query.period === '7d') {
    return 'Last 7 days'
  }
  if (query.period === '30d') {
    return 'Last 30 days'
  }
  if (query.period === 'month') {
    if (isThisMonth(site, query.date)) {
      return 'Month to Date'
    }
    return formatMonthYYYY(query.date)
  }
  if (query.period === '6mo') {
    return 'Last 6 months'
  }
  if (query.period === '12mo') {
    return 'Last 12 months'
  }
  if (query.period === 'year') {
    if (isThisYear(site, query.date)) {
      return 'Year to Date'
    }
    return formatYear(query.date)
  }
  if (query.period === 'all') {
    return 'All time'
  }
  if (query.period === 'custom') {
    return formatDateRange(site, query.from, query.to)
  }
  return 'Realtime'
}

function DatePicker() {
  const { query, otherSearch } = useQueryContext()
  const site = useSiteContext()
  const [isOpen, setOpen] = useState(false)
  const dropDownNode = useRef(null)
  const namedSelectablePeriodGroups = useSelectableDatePeriodGroups()

  useEffect(() => {
    setOpen(false)
  }, [query, otherSearch.calendar])

  const onClickOutsideClose = useCallback((e) => {
    if (dropDownNode.current && dropDownNode.current.contains(e.target)) {
      return
    }
    setOpen(false)
  }, [])

  useEffect(() => {
    document.addEventListener('mousedown', onClickOutsideClose, false)
    return () => {
      document.removeEventListener('mousedown', onClickOutsideClose, false)
    }
  }, [onClickOutsideClose])

  const flexRowClass = 'flex items-center justify-between'
  const linkClass = `px-4 py-2 text-sm leading-tight hover:bg-gray-100 hover:text-gray-900 dark:hover:bg-gray-900 dark:hover:text-gray-100`

  return (
    <div className="min-w-32 md:w-48 md:relative" ref={dropDownNode}>
      <div
        onClick={() => setOpen((currentState) => !currentState)}
        className="flex items-center justify-between rounded bg-white dark:bg-gray-800 shadow px-2 md:px-3
          py-2 leading-tight cursor-pointer text-xs md:text-sm text-gray-800
          dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900"
        tabIndex="0"
        role="button"
        aria-haspopup="true"
        aria-expanded="false"
        aria-controls="datemenu"
      >
        <span className="truncate mr-1 md:mr-2">
          <span className="font-medium">
            <DisplayPeriod />
          </span>
        </span>
        <ChevronDownIcon className="hidden sm:inline-block h-4 w-4 md:h-5 md:w-5 text-gray-500" />
      </div>
      <Transition
        show={isOpen}
        enter="transition ease-out duration-100"
        enterFrom="opacity-0 scale-95"
        enterTo="opacity-100 scale-100"
        leave="transition ease-in duration-75"
        leaveFrom="opacity-100 scale-100"
        leaveTo="opacity-0 scale-95"
      >
        {isOpen && (
          <div
            id="datemenu"
            className="absolute w-full left-0 right-0 md:w-56 md:absolute md:top-auto md:left-auto md:right-0 mt-2 origin-top-right z-10"
          >
            <div
              className="rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5
            font-medium text-gray-800 dark:text-gray-200 date-options"
            >
              {namedSelectablePeriodGroups.map((group, index) => (
                <div
                  key={index}
                  className={classNames(
                    'py-1 date-option-group border-gray-200 dark:border-gray-500 border-b last:border-none'
                  )}
                >
                  {group.map(({ navigation, keybind, button }) => (
                    <AppNavigationLink
                      key={button.label}
                      search={navigation.search}
                      className={classNames(flexRowClass, linkClass, {
                        'font-bold': navigation.isActive({ query })
                      })}
                    >
                      {button.label}
                      {!!keybind && (
                        <KeybindHint>{keybind.keyboardKey}</KeybindHint>
                      )}
                    </AppNavigationLink>
                  ))}
                </div>
              ))}
              {!COMPARISON_DISABLED_PERIODS.includes(query.period) && (
                <div
                  className={classNames(
                    'py-1 date-option-group border-gray-200 dark:border-gray-500 border-b last:border-none'
                  )}
                >
                  <AppNavigationLink
                    className={classNames(flexRowClass, linkClass)}
                    search={getComparisonSearch({ site, query })}
                  >
                    {isComparisonEnabled(query.comparison)
                      ? 'Disable comparison'
                      : 'Compare'}
                    <KeybindHint>X</KeybindHint>
                  </AppNavigationLink>
                </div>
              )}
            </div>
          </div>
        )}
      </Transition>
    </div>
  )
}

export default function N() {
  const site = useSiteContext()
  const { query, otherSearch } = useQueryContext()
  const visible = otherSearch.calendar === 'open'
  const navigate = useAppNavigate()

  const onCloseApplyPeriodIfPossible = ([selectionStart, selectionEnd]) => {
    if (!selectionStart || !selectionEnd) {
      return navigate({
        search: (search) => ({ ...search, calendar: null })
      })
    }
    const [from, to] = [
      parseNaiveDate(selectionStart),
      parseNaiveDate(selectionEnd)
    ]
    const singleDaySelected = from.isSame(to, 'day')

    if (singleDaySelected) {
      return navigateToQuery(navigate, query, {
        period: 'day',
        date: formatISO(from),
        from: null,
        to: null,
        calendar: null,
        keybindHint: null
      })
    }

    return navigateToQuery(navigate, query, {
      period: 'custom',
      date: null,
      from: formatISO(from),
      to: formatISO(to),
      calendar: null,
      keybindHint: null
    })
  }

  return (
    <div className="flex ml-auto pl-2">
      <DatePickerArrows />
      <DatePicker />
      <Transition
        show={visible}
        enter="transition ease-out duration-100"
        enterFrom="opacity-0 scale-95"
        enterTo="opacity-100 scale-100"
        leave="transition ease-in duration-75"
        leaveFrom="opacity-100 scale-100"
        leaveTo="opacity-0 scale-95"
      >
        <DateRangeCalendar
          onClose={onCloseApplyPeriodIfPossible}
          minDate={site.statsBegin}
          defaultDates={
            query.to && query.from
              ? [formatISO(query.from), formatISO(query.to)]
              : undefined
          }
        />
      </Transition>
    </div>
  )
}
