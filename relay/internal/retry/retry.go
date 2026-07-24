package retry

import "time"

// Do runs fn up to attempts times with a fixed sleep between failures.
func Do(attempts int, sleep time.Duration, fn func() error) error {
	if attempts < 1 {
		attempts = 1
	}
	var err error
	for i := 0; i < attempts; i++ {
		err = fn()
		if err == nil {
			return nil
		}
		if i < attempts-1 && sleep > 0 {
			time.Sleep(sleep)
		}
	}
	return err
}
