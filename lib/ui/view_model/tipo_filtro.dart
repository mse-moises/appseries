import '../../data/api_models/tipo_midia.dart';

/// Which kind of title a list shows: the home and the search share the choice's
/// shape, each with its own state.
enum TipoFiltro { todos, series, filmes }

/// The [TipoMidia] the filter keeps, or `null` for "Todos".
///
/// A title of an unknown kind (server newer than the app) only passes "Todos":
/// it is neither a series nor a movie as far as this app knows.
TipoMidia? tipoDoFiltro(TipoFiltro filtro) => switch (filtro) {
      TipoFiltro.todos => null,
      TipoFiltro.series => TipoMidia.tv,
      TipoFiltro.filmes => TipoMidia.movie,
    };
