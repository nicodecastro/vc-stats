import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/backup_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/games_page.dart';
import 'pages/reconcile_page.dart';
import 'pages/reports_page.dart';
import 'pages/tournament_detail_page.dart';
import 'pages/tournaments_page.dart';
import 'pages/tracker_page.dart';
import 'shell.dart';
import 'theme.dart';

class VcSetsApp extends StatelessWidget {
  VcSetsApp({super.key});

  final GoRouter _router = GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/tournaments',
            builder: (context, state) => const TournamentsPage(),
          ),
          GoRoute(
            path: '/tournaments/:tournamentId',
            builder: (context, state) => TournamentDetailPage(
              tournamentId: state.pathParameters['tournamentId']!,
            ),
          ),
          GoRoute(
            path: '/games',
            builder: (context, state) => const GamesPage(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/backup',
            builder: (context, state) => const BackupPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/tournaments/:tournamentId/games/:gameId/track',
        builder: (context, state) => TrackerPage(
          tournamentId: state.pathParameters['tournamentId']!,
          gameId: state.pathParameters['gameId']!,
        ),
      ),
      GoRoute(
        path: '/tournaments/:tournamentId/games/:gameId/reconcile',
        builder: (context, state) => ReconcilePage(
          tournamentId: state.pathParameters['tournamentId']!,
          gameId: state.pathParameters['gameId']!,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'VC SETS',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    routerConfig: _router,
  );
}
