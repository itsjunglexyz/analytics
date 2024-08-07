/* @format */
import React from 'react'
import { ArrowKeybind } from './datepicker'
import { NavigateKeybind } from './keybinding'
import {
  getComparisonSearch,
  last6MonthsOptions,
  useSelectableDatePeriodGroups
} from './query-time-periods'
import { useSiteContext } from './site-context'
import { useQueryContext } from './query-context'

export function DashboardKeybinds() {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const groups = useSelectableDatePeriodGroups()
  groups.concat([last6MonthsOptions])
  return (
    <>
      <ArrowKeybind keyboardKey="ArrowLeft" />
      <ArrowKeybind keyboardKey="ArrowRight" />
      {groups.flatMap((group) =>
        group
          .filter(({ keybind }) => !!keybind)
          .map(({ keybind, navigation }) => (
            <NavigateKeybind
              key={keybind.keyboardKey}
              {...keybind}
              navigateProps={{ search: navigation.search }}
            />
          ))
      )}
      <NavigateKeybind
        keyboardKey="X"
        type="keydown"
        navigateProps={{
          search: (search) => ({
            ...search,
            keybindHint: 'X',
            filters: null,
            labels: null
          })
        }}
      />
      <NavigateKeybind
        keyboardKey="Escape"
        type="keyup"
        navigateProps={getComparisonSearch({ site, query })}
      />
    </>
  )
}
