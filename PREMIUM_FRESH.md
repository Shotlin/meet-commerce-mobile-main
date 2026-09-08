# Premium Fresh product sections

In Theme Builder → section library, choose **Premium Fresh — Product Slider**, **Product Grid**, **Large Photo Cards**, or **Wide Image Slides**. Existing product grids and carousels without an explicit card style now use Premium Fresh. Explicit compact and legacy styles remain supported.

Product section config uses `product_card_style: PREMIUM_FRESH`, `title`, `subtitle`, and `columns` (1 for large cards, 2 for a grid). Product rails use large borderless photos with a floating crimson plus; grids use rounded white cards with a soft shadow and crimson Add control. Wide promotional slides use the existing custom banner uploader and `aspect_ratio: 5:1`.

Upload product photography one image at a time in Products → Edit product → Images. Saved image order controls the swipeable gallery in grid cards; rails use the first image. For the reference's photographic feel, upload full-frame product photography: existing artwork with text or padding retains that artwork. No reference screenshots are inserted as product images.

Descriptions, unit/weight, `highlights.pieces`, `highlights.serves`, effective price, original price, discounts, and delivery minutes come from actual catalog data. Missing details are omitted. The design does not invent delivery promises, serving sizes, or promotional prices.

Validation: dashboard production build and type check; browser inspection of rail and large-card preview, including photo dot selection; Flutter widget tests for narrow/full-width cards at 150% text scale, cart quantity rendering, and product-option selection. Live publishing and a new mobile app release are separate from these source changes.
