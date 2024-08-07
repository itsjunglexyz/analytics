/* @format */
import React, { useEffect, useRef } from 'react'
import Flatpickr from 'react-flatpickr'

export function DateRangeCalendar({ minDate,maxDate, defaultDates, onClose }) {
  const calendarRef = useRef(null)

  useEffect(() => {
    const calendar = calendarRef.current
    if (calendar) {
      calendar.flatpickr.open()
    }

    return () => calendar && calendar.flatpickr?.destroy()
  }, [])


  return (
    <div className="h-0 w-0">
      <Flatpickr
        id="calendar"
        options={{
          mode: 'range',
          maxDate,
          minDate,
          defaultDates,
          showMonths: 1,
          static: true,
          animate: true
        }}
        ref={calendarRef}
        onClose={onClose}
        className={'invisible'}
      />
    </div>
  )
}
