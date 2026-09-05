# NuanceOS

NuanceOS est un assistant personnel iOS orienté résultats. L'utilisateur parle normalement de ce qu'il veut changer ; Nuance comprend sa situation, pose les questions qui comptent, construit un plan et transforme ce plan en prochaine action claire.

## Expérience actuelle

- Conversation guidée plutôt qu'un formulaire
- Apple Foundation Models / Apple Intelligence quand disponible
- Moteur local de secours si le modèle Apple n'est pas disponible
- Questions adaptatives avant de conseiller
- Résumé de la situation et faits compris
- Plans personnalisés enregistrés comme projets
- Onglet **Aujourd'hui** avec une seule priorité principale
- Progression par projet et étapes cochables
- Partage d'une priorité ou d'un plan
- Interface SwiftUI modernisée avec cartes, matériaux, progression et hiérarchie visuelle

## Philosophie produit

Nuance ne doit pas être un chatbot qui donne des listes de conseils. Le produit suit une boucle simple :

**Comprendre → décider → agir → mesurer → adapter.**

Les intégrations externes (documents, photos, rappels, calendrier, synchronisation iCloud et autres outils) doivent venir enrichir cette boucle sans la compliquer.

## Ouvrir dans Xcode

Ouvrir `NuanceOS.xcodeproj`, choisir la Team Apple dans Signing & Capabilities si nécessaire, sélectionner l'iPhone puis lancer avec `⌘R`.

## Structure

- `NuanceOS/App` : point d'entrée
- `NuanceOS/Views` : expérience assistant, focus quotidien et projets
- `NuanceOS/Models` : modèles de données
- `NuanceOS/Services` : moteur local et stockage
- `NuanceOS/Resources` : ressources de l'application
