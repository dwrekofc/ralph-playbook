# Product Specification

## Overview

A simple recipe sharing web app where users can create, browse, search, and favorite recipes. Single-user, local-first.

## Features

### Feature 1: Recipe CRUD

**User Story:** As a user, I want to create, view, edit, and delete recipes, so that I can manage my recipe collection.

**Success Criteria:**
1. User can create a recipe with title, ingredients list, instructions, and optional image URL
2. User can view a single recipe with all its details
3. User can edit any field of an existing recipe
4. User can delete a recipe with a confirmation prompt

**Eval Rubric:**
- **Pass:** All four CRUD operations work correctly. Data persists across page reloads.
- **Fail:** Any CRUD operation is broken, data doesn't persist, or forms don't validate.
- **Weight:** 5

### Feature 2: Recipe Search

**User Story:** As a user, I want to search recipes by title or ingredient, so that I can quickly find what I'm looking for.

**Success Criteria:**
1. Search box is visible on the main page
2. Typing a query filters recipes in real-time (or on submit)
3. Search matches against recipe title AND ingredients
4. Empty search shows all recipes

**Eval Rubric:**
- **Pass:** Search returns correct results for title and ingredient queries. No false negatives.
- **Fail:** Search doesn't work, returns wrong results, or only searches one field.
- **Weight:** 4

### Feature 3: Favorites

**User Story:** As a user, I want to mark recipes as favorites, so that I can quickly access my most-used recipes.

**Success Criteria:**
1. Each recipe has a favorite toggle (heart/star icon)
2. Favorited recipes appear in a "Favorites" section or filter
3. Favorite status persists across page reloads

**Eval Rubric:**
- **Pass:** Can favorite/unfavorite recipes. Favorites filter works. State persists.
- **Fail:** Favorite toggle broken, filter doesn't work, or state doesn't persist.
- **Weight:** 3

### Feature 4: Tags

**User Story:** As a user, I want to tag recipes with categories (e.g., "breakfast", "quick", "vegetarian"), so that I can organize and filter by category.

**Success Criteria:**
1. User can add tags when creating or editing a recipe
2. Tags are displayed on recipe cards and detail view
3. User can filter recipes by clicking a tag

**Eval Rubric:**
- **Pass:** Tags can be added, displayed, and used for filtering.
- **Fail:** Tags can't be added, don't display, or filtering doesn't work.
- **Weight:** 3

### Feature 5: Responsive Layout

**User Story:** As a user, I want the app to look good on desktop and mobile, so that I can use it from any device.

**Success Criteria:**
1. Recipe list displays as a grid on desktop, single column on mobile
2. Navigation is usable on mobile (no overflow, touch-friendly targets)
3. Recipe detail page is readable on all screen sizes

**Eval Rubric:**
- **Pass:** Layout adapts correctly at 3 breakpoints: mobile (<640px), tablet (640-1024px), desktop (>1024px).
- **Fail:** Layout breaks at any breakpoint or content overflows.
- **Weight:** 2

## Cross-Cutting Requirements

- All data stored in SQLite via Drizzle ORM
- All forms must validate required fields before submission
- Loading states for async operations
- Error messages displayed for failed operations

## Out of Scope

- No user authentication (single-user app)
- No image upload (URL only)
- No recipe sharing or social features
- No print-friendly layout
