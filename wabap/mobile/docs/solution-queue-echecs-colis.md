# Solution : Queue d'échecs locale pour les mutations de colis

## Contexte du problème

**Symptôme observé** : Lors de la validation de pickup d'une tournée, certains colis (typiquement 10 consécutifs sur 100+) restent en statut `PENDING` en DynamoDB au lieu d'être mis à jour avec `NOT_PICKED_UP_NOT_EXIST` ou autre. Le livreur ne s'en aperçoit qu'en phase de livraison, où il doit les marquer manuellement comme `ISSUE`.

**Cause identifiée** : Coupure réseau micro (3–5 secondes) sur le téléphone du livreur pendant la validation. Les requêtes en vol dans le `Pool(15)` échouent toutes en même temps, `retryOnce` retente sans délai (échec immédiat), erreurs avalées silencieusement par les `try/catch`, le livreur croit que tout est passé.

**Élimination des autres causes** (validée via CloudWatch sur l'incident du 11 mai 2026) :
- Aucun throttling DynamoDB (tables ni GSI)
- Aucune erreur 4XX ou 5XX côté AppSync (donc pas d'expiration token, pas de throttling AppSync)
- Latence base normale (~20ms)

Les requêtes ne sont **jamais arrivées** au serveur → problème côté client.

---

## Solution fonctionnelle

### Principe

Une **file d'échecs locale persistante** sur le téléphone. Chaque mutation `updateStatusColis` qui échoue après les retries est sauvegardée localement et re-tentée à des moments opportuns (sans intervention du livreur dans la plupart des cas).

### Expérience utilisateur

**Cas normal (95% du temps)** : Aucune différence avec l'état actuel. Le livreur scanne, valide, livre.

**Cas avec incident** :
1. Le livreur valide une tournée → 10 colis échouent silencieusement (comme aujourd'hui), mais sont enregistrés en local
2. Retour HomeScreen → petit badge discret affichant "⚠️ 10 colis en attente de synchronisation"
3. Le livreur continue normalement (clique sur la tournée, livre un colis)
4. Au clic sur la tournée, l'app tente automatiquement de vider la queue en arrière-plan
5. Si le réseau est revenu → les 10 colis sont synchronisés en quelques secondes → badge disparaît
6. Le livreur ne s'aperçoit de rien — la magie a opéré

**Cas dégradé** :
- Si le réseau reste mauvais toute la journée → badge reste affiché
- Le livreur peut taper sur le badge pour forcer un retry manuel
- Au pire, retry au démarrage du lendemain

**Le livreur n'est jamais bloqué.** La queue tourne en parallèle de son workflow normal.

---

## Architecture technique

### Composants

| Composant | Rôle | Localisation |
|---|---|---|
| `PendingMutationsQueue` | Singleton de gestion de la queue locale | `lib/services/pending_mutations_queue.dart` (nouveau) |
| Stockage persistant | Conserver la queue entre les sessions | `shared_preferences` (déjà disponible) ou `hive` |
| Triggers de retry | Appeler `tryFlush()` aux bons moments | `tournee_screen.dart`, `main.dart` |
| Badge UI | Afficher "X en attente" + bouton manuel | `home_screen.dart` |

### Modèle de données local

Chaque entrée de la queue contient :

```
{
  colisId: String           // ID du colis à mettre à jour
  status: Status             // Statut à appliquer (NOT_PICKED_UP_NOT_EXIST, PICKED_UP, ISSUE, etc.)
  message: String?           // Message optionnel
  position: Position?        // Position GPS optionnelle
  timestamp: DateTime        // Quand l'échec s'est produit (pour ordre et debug)
  attemptCount: int          // Nombre de tentatives déjà faites
}
```

### Flux de capture des échecs

Modifier les blocs `catch (e)` dans `validatePickingUpColis` et `validateDeliveryColis` (`signature_view.dart`) :

```
Aujourd'hui :
  catch (e) {
    safePrint("Status update failed even after retry: $e");
  }

Demain :
  catch (e) {
    safePrint("Status update failed even after retry: $e");
    await PendingMutationsQueue.instance.enqueue(
      colisId: colisInTournee.colis.id,
      status: statusColis,
      message: message,
      position: _lastPosition,
    );
  }
```

### Flux de retry

`PendingMutationsQueue.tryFlush()` :

```
1. Si la queue est vide → return immédiat (aucun appel backend)
2. Si dernier essai < 30 secondes → return (debounce)
3. Sinon :
   Pour chaque entrée de la queue :
     a) Lire le statut actuel du colis côté backend
     b) Si statut != PENDING → l'entrée a été supplantée par une action récente,
                                 supprimer l'entrée sans appliquer
     c) Si statut == PENDING → appliquer la mutation via updateStatusColis
        - Si succès → supprimer l'entrée de la queue
        - Si échec → incrémenter attemptCount, garder l'entrée
4. Sauvegarder l'état de la queue
```

La **vérification du statut avant retry** (étape b) est cruciale : elle évite d'écraser une action plus récente du livreur (cas où il aurait marqué le colis comme ISSUE en livraison entre-temps).

### Triggers de retry

Trois déclencheurs naturels :

| Trigger | Code | Fréquence dans la journée |
|---|---|---|
| Ouverture de TourneeScreen | Dans `useEffect` de `tournee_screen.dart` | 50–100+ fois (principal) |
| Démarrage de l'app | Dans `initApp` de `main.dart` | 1–3 fois |
| Tap sur badge HomeScreen | Sur l'`onTap` du badge | À la demande |

Tous appellent `PendingMutationsQueue.instance.tryFlush()` sans attendre le résultat (fire-and-forget).

### Affichage du badge

Dans HomeScreen, ajouter un `ValueListenableBuilder` ou `ref.watch` sur `PendingMutationsQueue.instance.lengthNotifier` :

```
Si queue.length == 0 → ne rien afficher
Sinon → afficher un bandeau orange discret avec :
       - Icône d'alerte
       - Texte "X colis en attente de synchronisation"
       - Bouton "Réessayer" qui appelle tryFlush() ignorant le debounce
```

---

## Modifications nécessaires

| Fichier | Type | Estimation lignes |
|---|---|---|
| `lib/services/pending_mutations_queue.dart` | Nouveau fichier | ~150 lignes |
| `lib/screen/preuve_livraison/signature_view.dart` | Modifier 2 `catch (e)` blocks | ~10 lignes |
| `lib/screen/tournee_screen.dart` | Ajouter une ligne dans `useEffect` | ~3 lignes |
| `lib/main.dart` | Appeler `tryFlush()` dans `initApp` | ~3 lignes |
| `lib/screen/home_screen.dart` | Ajouter le badge conditionnel | ~30 lignes |
| **Total** | | **~200 lignes** |

**Aucun changement** sur le schéma backend, l'authentification, le scan, la signature, ou les autres providers.

---

## Cas particuliers gérés

| Cas | Comportement |
|---|---|
| Queue vide + ouverture TourneeScreen | `tryFlush()` return immédiatement, aucun appel backend |
| Plusieurs ouvertures TourneeScreen en 10 secondes | Debounce 30s évite le spam |
| Le réseau revient après une coupure | Prochain `tryFlush()` vide la queue normalement |
| Livreur change le statut d'un colis ailleurs entre l'échec et le retry | Vérification du statut backend → l'entrée queue est ignorée et supprimée |
| App fermée pendant la nuit avec queue non vide | Retry au prochain démarrage le matin |
| Désinstallation de l'app avec queue non vide | Perte de la queue (acceptable car le serveur reste cohérent, le bug initial réapparaîtra mais le livreur peut intervenir manuellement) |

---

## Test manuel

1. **Test du cas nominal** : Faire une tournée complète avec wifi OK → vérifier que la queue reste vide tout du long, aucun badge n'apparaît
2. **Test du cas avec coupure** :
   - Activer le mode avion juste avant d'appuyer sur "Valider" pickup
   - Vérifier dans les logs que les erreurs sont bien capturées dans la queue
   - Vérifier que le badge apparaît sur HomeScreen avec le bon compte
   - Réactiver le réseau
   - Ouvrir TourneeScreen → vérifier que la queue se vide (logs + badge disparaît)
3. **Test du conflit** :
   - Provoquer un échec sur 1 colis (mode avion pendant validation)
   - Activer le réseau, MAIS avant que le badge ne disparaisse, naviguer en phase delivery et marquer ce colis comme ISSUE
   - Ouvrir TourneeScreen → le retry doit voir que le colis n'est plus PENDING et supprimer l'entrée sans écraser le ISSUE
4. **Test du debounce** :
   - Provoquer un échec, garder le mode avion activé
   - Ouvrir TourneeScreen 20 fois rapidement
   - Vérifier dans les logs qu'il n'y a pas eu 20 tentatives mais beaucoup moins (espacement de 30s minimum)
5. **Test de persistence** :
   - Provoquer un échec, fermer complètement l'app (force quit)
   - Rouvrir l'app → vérifier que la queue est toujours là et que le retry se déclenche

---

## Effort estimé

| Phase | Durée |
|---|---|
| Implémentation | 1 jour |
| Tests manuels | 1 jour |
| **Total** | **2 jours** |

---

## Trade-offs et limites

| Limite | Impact |
|---|---|
| Pas de vrai mode offline (le pickup nécessite encore une connexion initiale pour charger la liste) | Acceptable : le bug actuel n'est pas un mode offline complet |
| Queue perdue si app désinstallée | Acceptable : très rare |
| Pas de retry périodique automatique en arrière-plan (app fermée) | Acceptable : les triggers naturels couvrent le besoin |
| Pas de visibilité côté serveur sur les incidents | À considérer : ajouter optionnellement un endpoint `logClientFailure(colisId, reason)` pour avoir des métriques CloudWatch |
| Conflits de concurrence avec un autre device (rare) | Géré par la vérification de statut avant retry |

---

## Activation différée

Cette solution n'est **pas urgente à activer**. À considérer comme une **assurance** à mettre en place :
- **Si le bug se reproduit** plusieurs fois et impacte le travail des livreurs
- **Si un client le remonte** comme un problème opérationnel à résoudre
- **Pour durcir l'app** dans une future itération de maintenance

D'ici là, le workaround opérationnel (livreur qui voit les colis en PENDING en livraison et les marque ISSUE) fonctionne et limite les dégâts.

---

## Pour reprendre quand prêt

Quand on décide d'implémenter :
1. Relire ce document
2. Écrire le code concret de `PendingMutationsQueue` + les modifications dans les 4 fichiers existants
3. Tester selon le plan ci-dessus
4. Inclure dans une release dédiée (pas dans une release en cours pour éviter de bouger trop de choses)

Pour aller plus loin un jour (vrai mode offline, sync delta, etc.) : basculer vers Amplify DataStore.

---

## Évolutions possibles (au-delà de cette solution)

- **Niveau 2** : Cache local des colis + sync en arrière-plan via `workmanager` (effort ~1-2 semaines, permet du vrai offline pendant la pickup)
- **Niveau 3** : Migration vers Amplify DataStore (effort ~3-4 semaines, local-first complet, géré par Amplify)

Ces évolutions ne sont à considérer que si le Niveau 1 (ce document) s'avère insuffisant en pratique.
