import '../../data/api_models/tipo_midia.dart';

/// Which kind of title a list shows: the home and the search share the choice's
/// shape, each with its own state.
enum FiltroTipo { todos, series, filmes }

/// The [TipoMidia] the filter keeps, or `null` for "Todos".
///
/// A title of an unknown kind (server newer than the app) only passes "Todos":
/// it is neither a series nor a movie as far as this app knows.
TipoMidia? tipoDoFiltro(FiltroTipo filtro) => switch (filtro) {
      FiltroTipo.todos => null,
      FiltroTipo.series => TipoMidia.tv,
      FiltroTipo.filmes => TipoMidia.movie,
    };
