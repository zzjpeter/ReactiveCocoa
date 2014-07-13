//
//  Consumer.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-03.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

func _emptyNext(value: Any) {}
func _emptyError(error: NSError) {}
func _emptyCompleted() {}

/// Receives events from a Producer.
@final class Consumer<T>: Sink {
	typealias Element = Event<T>

	let _sink: Atomic<SinkOf<Element>?>

	/// A list of Disposables to dispose of when the consumer receives
	/// a terminating event, or if event production is canceled.
	let disposable = CompositeDisposable()

	/// Initializes a Consumer that will forward events to the given sink.
	init<S: Sink where S.Element == Event<T>>(_ sink: S) {
		_sink = Atomic(SinkOf(sink))

		// This is redundant with the behavior of put() in case of
		// a terminating event, but ensures that we get rid of the closure
		// upon cancellation as well.
		disposable.addDisposable {
			self._sink.value = nil
		}
	}

	/// Initializes a Consumer that will perform the given action whenever an
	/// event is received.
	convenience init(put: Event<T> -> ()) {
		self.init(SinkOf(put))
	}

	/// Initializes a Consumer with zero or more different callbacks, based
	/// on the type of Event received.
	convenience init(next: T -> () = _emptyNext, error: NSError -> () = _emptyError, completed: () -> () = _emptyCompleted) {
		self.init(SinkOf<Element> { event in
			switch event {
			case let .Next(value):
				next(value)

			case let .Error(err):
				error(err)

			case let .Completed:
				completed()
			}
		})
	}

	func put(event: Event<T>) {
		let oldSink = _sink.modify { s in
			if event.isTerminating {
				return nil
			} else {
				return s
			}
		}
		
		oldSink?.put(event)

		if event.isTerminating {
			disposable.dispose()
		}
	}
}
