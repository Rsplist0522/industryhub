
delete from public.training_programmes
where id in ('cnc-setup', 'lean-essentials', 'quality-systems', 'welding-safety', 'supervision');

delete from public.msic_codes
where item_code in ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'M', 'N');

delete from public.data_sources
where id in (
  'skillmatch-upskill-malaysia',
  'fairprice-world-bank-pink-sheet',
  'fairprice-malaysia-ppi',
  'resource-profile-msic',
  'marketplace-state-industry-context'
);

delete from public.commodity_price_observations
where source_name = 'World Bank Commodity Price Data (Pink Sheet)'
  and observed_on = date '2024-12-01';

delete from public.price_index_observations
where dataset_id = 'ppi'
  and observed_on = date '2026-06-01';

delete from public.industry_context_observations
where source_name = 'Department of Statistics Malaysia'
  and observed_on = date '2025-01-01';
