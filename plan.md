# ✅ COMPLETE: Restrict User Image Deletion & Fix CI Integration Tests (#14493)

## Goal Description
Resolve issue #14493 ("Let a user remove the pictures uploaded by them") and fix CI integration test failures:
1. **Backend Authorization & Grace Period**: Allow users to remove (move to trash) images uploaded by themselves within a 24-hour grace period (`86400` seconds). Restrict image deletions for images >24h old to moderators to safeguard dataset integrity under CC-BY.
2. **API v3 Support**: Enforce the 24-hour upload window for non-moderators deleting images via API v3 in `lib/ProductOpener/APIProductImagesUpload.pm`.
3. **Frontend & Template Fixes**: Display `manage_images_accordion` in `templates/web/pages/product_edit/product_edit_form_display.tt.html` to logged-in users while keeping `move_images` moderator-only. Add null checks in `html/js/product-multilingual.js` for `#move_images` to prevent JS `TypeError`s.
4. **Unit Tests**: Add unit tests in `tests/unit/images.t` for 24-hour window enforcement and moderator overrides.
5. **CI Integration Tests**: Fix test snapshot expectations in `tests/integration/expected_test_results/product_write/post-product-search-or-add.html`, `tests/integration/expected_test_results/web_html/world-edit-product.html`, and `tests/integration/expected_test_results/web_html/fr-edit-product.html` for edit forms displayed to logged-in non-moderator users.

## Implementation Steps
- [x] Step 1: Update `lib/ProductOpener/Images.pm` to check `uploaded_t` (24h window) for non-moderators deleting own images.
- [x] Step 2: Update `lib/ProductOpener/APIProductImagesUpload.pm` to enforce 24-hour grace period for non-moderators on API v3.
- [x] Step 3: Update `templates/web/pages/product_edit/product_edit_form_display.tt.html` and `html/js/product-multilingual.js` with non-moderator image management and JS null checks.
- [x] Step 4: Add comprehensive unit tests in `tests/unit/images.t` covering authorization, 24-hour window expiration, and moderator overrides.
- [x] Step 5: Update integration test expected HTML snapshots in `tests/integration/expected_test_results/product_write/` and `tests/integration/expected_test_results/web_html/` to match `manage_images_accordion` rendered for logged-in users.
- [x] Step 6: Commit with DCO sign-off (`Signed-off-by`) and push to remote `fork/fix/14493-user-remove-own-pictures`.

## Implementation Progress
- [x] Step 1: `lib/ProductOpener/Images.pm` authorization logic updated.
- [x] Step 2: `lib/ProductOpener/APIProductImagesUpload.pm` updated for API v3.
- [x] Step 3: `product_edit_form_display.tt.html` and `html/js/product-multilingual.js` updated.
- [x] Step 4: Unit tests added in `tests/unit/images.t`.
- [x] Step 5: Updated HTML snapshot files in `product_write` and `web_html` integration test expected results (`post-product-search-or-add.html`, `world-edit-product.html`, `fr-edit-product.html`).
- [x] Step 6: Pushed commit `633fb63` with DCO sign-off to `fork/fix/14493-user-remove-own-pictures`.

## Notes & Decisions
- 24-hour grace period (86400 seconds) balances user error correction with CC-BY open database licensing integrity.
- Admin check updated in `process_image_move` (`$User{moderator} || $User{admin} || is_admin_user($user_id)`) to ensure system admins retain override authority.
- Integration test snapshots in `product_write` and `web_html` reflect the intentional display of image management options (`manage_images_accordion`) to logged-in users.
