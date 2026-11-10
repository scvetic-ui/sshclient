import 'package:flutter/material.dart';

import 'background.dart';
import 'forwarding.dart';
import 'prompter.dart';
import 'sessions.dart';
import 'store.dart';

/// Working name — change here to rename the app UI.
const appName = 'LemonSSH';

/// Main color of the menu bar — change to taste.
const kBrand = Color(0xFF00838F);

final store = Store();
final prompter = Prompter();
final sessions = SessionManager();
final forwards = ForwardManager();
final background = Background();
