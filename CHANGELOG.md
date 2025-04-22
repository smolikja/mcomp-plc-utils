# Changelog

## [Unreleased]

### Added
- **ConfigFetcher**
  - Implementace cachingu pomocí SharedPreferences
  - Přidání typové bezpečnosti s rozhraním `PlcConfig`
  - Implementace repository patternu s `ConfigRepository`
  - Konfigurovatelná doba platnosti cache
  - Možnost vynutit obnovení z remote zdroje
  - Fallback na cache při selhání síťových požadavků

- **EmailReporting**
  - Odstranění závislosti na globální proměnné `appFlavor`
  - Přidání metody `initialize` pro konfiguraci
  - Možnost nastavit `appFlavor` pro jednotlivé reporty
  - Lepší logování a zpracování chyb

- **WebSocket**
  - Automatické znovupřipojení s exponenciálním backoff algoritmem
  - Heartbeat mechanismus pro detekci "mrtvých" spojení
  - Lepší zpracování chyb a logování
  - Konfigurovatelné parametry pro znovupřipojení
  - Řešení potenciálních memory leaks
  - Optimalizace pro velké množství připojení

- **ResizableBottomSheet**
  - Rozšířené možnosti přizpůsobení vzhledu pomocí `BottomSheetAppearance`
  - Implementace podpory pro keyboard avoidance
  - Přidání podpory pro snap points
  - Callback při zavření bottom sheetu
  - Konfigurovatelné chování (dismissible, enableDrag, useSafeArea)

### Changed
- Vylepšená dokumentace pro všechny komponenty
- Aktualizované příklady použití
- Lepší typová bezpečnost napříč knihovnou

### Fixed
- Opraveny potenciální memory leaks ve WebSocket implementaci
- Vyřešeny problémy s odpojením WebSocket
- Zlepšena stabilita při síťových chybách

## [0.0.1] - 2023-XX-XX

### Added
- Initial release
