-- auction-images: photos shown on auctions. Created in a migration (not config.toml) so
-- the hosted project gets the same bucket and limits as local.
-- Public bucket: anyone can fetch a photo by its URL without a policy.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'auction-images',
  'auction-images',
  true,
  5 * 1024 * 1024,
  array['image/jpeg', 'image/png', 'image/webp']
);

-- Uploads go to '<user_id>/<file>'. The auctions insert policy checks the same folder,
-- so an auction can only point at its seller's own photos.
create policy "Users upload auction images to their own folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'auction-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Needed for delete (the Storage API reads the row it removes); lets the app clean up a
-- photo when creating the auction fails. Owners only; others use the public URL.
create policy "Users read their own auction images"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'auction-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users delete their own auction images"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'auction-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
