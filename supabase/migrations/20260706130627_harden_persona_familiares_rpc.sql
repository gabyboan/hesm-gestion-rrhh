drop policy if exists persona_familiares_select_legajo_editor
  on public.persona_familiares;

create policy persona_familiares_select_authorized
on public.persona_familiares
for select
to authenticated
using (
  private.has_legajo_edit_role()
  or public.can_medicos_read()
);

alter function public.rpc_medicos_familiares(bigint) security invoker;
