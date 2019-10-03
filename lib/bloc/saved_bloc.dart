import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:telfaza/bloc/bloc_base.dart';
import 'package:telfaza/models/movie.dart';
import 'package:telfaza/services/db_service.dart';
import 'package:telfaza/services/tmdb_api.dart';

class SavedBloc extends BaseBloc {
  final DBService _dbService;

  StreamSubscription _sub;
  bool _shouldRes = true;
  List<Movie> _favorites = [];

  BehaviorSubject<List<Movie>> _favoritesSubject = BehaviorSubject<List<Movie>>.seeded([]);
  Stream<List<Movie>> get outFavorites => _favoritesSubject.stream;
  Sink<List<Movie>> get _inFavorites => _favoritesSubject.sink;

  BehaviorSubject<Map<String, dynamic>> _addFavoriteSubject = BehaviorSubject<Map<String, dynamic>>();
  Stream<Map<String, dynamic>> get _outAddFavorites => _addFavoriteSubject.stream;
  Sink<Map<String, dynamic>> get inAddFavorites => _addFavoriteSubject.sink;

  BehaviorSubject<bool> _restartSubject = BehaviorSubject<bool>.seeded(true);
  Stream<bool> get _outRestart => _restartSubject.stream;
  Sink<bool> get inRestart => _restartSubject.sink;


  SavedBloc(this._dbService) {
    _outRestart.listen((b) {
      if (!b) {
        _shouldRes = true;
      } else {
        if (_shouldRes)
          subscribe();
        _shouldRes = false;
    }
    });
    _outAddFavorites.listen((event) {
      final Movie movie = event['movie'];
      if (event['add'] == 0) {
        _favorites.remove(movie);
        _dbService.removeFavorite(movie.id);
      } else {
        _favorites.add(movie);
        _dbService.addFavorite(movie.id);
      }
      _inFavorites.add(_favorites);
    });
  }

  void subscribe() {
    _sub?.cancel();
    _dbService.outFavorites.then((stream) { _sub = stream.listen(convert);});
  }

   void convert(QuerySnapshot snapshot) async {
    final List<Future<Movie>> futures = [];
    for (var doc in snapshot.documents)
      futures.add(api.getMovieById(doc['movie']));
    // if I directly assign the result to _favorites, I get the following error
    // when I try to add a movie to _favorites, I have no clue what's the reason
    //Unhandled Exception: type 'Movie' is not a subtype of type 'Null' of 'value'
    final res = await Future.wait(futures);
    _favorites.clear();
    _favorites.addAll(res);
    _inFavorites.add(_favorites);
  }

  @override
  void dispose() {
    _favoritesSubject.close();
    _addFavoriteSubject.close();
    _restartSubject.close();
    _sub.cancel();
  }

}