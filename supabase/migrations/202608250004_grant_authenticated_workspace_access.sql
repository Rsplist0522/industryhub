-- Restore the table privileges required by the Flutter client.
-- Row Level Security remains active; these grants do not bypass ownership policies.

grant usage on schema public to authenticated;

grant select, insert, update, delete on table public.profiles to authenticated;
grant select, insert, update, delete on table public.listings to authenticated;
grant select, insert, update, delete on table public.deal_requests to authenticated;
grant select, insert, update, delete on table public.saved_matches to authenticated;
grant select, insert, update, delete on table public.fair_price_sessions to authenticated;

grant select on table public.training_programmes to authenticated;
grant select on table public.workforce_skill_signals to authenticated;
grant select on table public.msic_codes to authenticated;
grant select on table public.data_sources to authenticated;
grant select on table public.commodity_price_observations to authenticated;
grant select on table public.price_index_observations to authenticated;
grant select on table public.industry_context_observations to authenticated;
