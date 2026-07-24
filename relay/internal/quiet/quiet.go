package quiet

import "time"

// Hours defines a quiet window in local clock hours [0,24).
// When Start == End, quiet hours are disabled.
// When Start > End, the window wraps past midnight (e.g. 22→7).
type Hours struct {
	Start int // inclusive hour
	End   int // exclusive hour
}

func (h Hours) Contains(t time.Time) bool {
	if h.Start == h.End {
		return false
	}
	hour := t.Hour()
	if h.Start < h.End {
		return hour >= h.Start && hour < h.End
	}
	// wraps midnight
	return hour >= h.Start || hour < h.End
}
