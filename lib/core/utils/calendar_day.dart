/// Midnight of the calendar day [days] after [date]'s day.
///
/// Not `date.add(Duration(days: days))`: a day that crosses a daylight saving
/// change is 23 or 25 hours long, so adding 24h lands an hour off midnight.
DateTime addCalendarDays(DateTime date, int days) => DateTime(date.year, date.month, date.day + days);
