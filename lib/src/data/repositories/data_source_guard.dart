import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';

/// Runs a data source call and turns its exceptions into [L10nFailure]s.
///
/// Errors (bugs such as a `TypeError`) are not caught.
Future<Either<L10nFailure, T>> guardCall<T>(Future<T> Function() call) async {
  try {
    return Right(await call());
  } on Exception catch (e) {
    return Left(failureFor(e));
  }
}

/// Emits each event of [stream] as a [Right] and each exception as a [Left],
/// so a failed read is shown without ending the stream.
Stream<Either<L10nFailure, T>> guardStream<T>(Stream<T> stream) =>
    stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) => sink.add(Right(data)),
        handleError: (error, stackTrace, sink) {
          if (error is Exception) {
            sink.add(Left(failureFor(error)));
          } else {
            sink.addError(error, stackTrace);
          }
        },
      ),
    );

/// The failure shown for exception [e].
L10nFailure failureFor(Exception e) => switch (e) {
  L10nDataSourceException(:final message) => DataSourceFailure(message),
  _ => UnexpectedFailure('$e'),
};
