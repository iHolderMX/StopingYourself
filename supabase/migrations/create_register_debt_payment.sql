-- Registro atomico de un pago a una deuda.
--
-- Problema que resuelve: el cliente hacia dos llamadas sueltas (insertar el
-- pago y luego actualizar paid_amount). Si la segunda fallaba, el pago quedaba
-- huerfano y la deuda mostraba un saldo equivocado de forma permanente.
-- Aqui ambos pasos ocurren en la misma transaccion del servidor.
--
-- Es SECURITY INVOKER a proposito: la funcion corre con los permisos de quien
-- la llama, asi que las politicas RLS de debts y debt_payments siguen
-- aplicando y un usuario no puede tocar deudas ajenas.

create or replace function public.register_debt_payment(
  p_payment_id   text,
  p_debt_id      text,
  p_amount       numeric,
  p_note         text        default null,
  p_payment_date timestamptz default now()
)
returns public.debts
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_debt      public.debts;
  v_remaining numeric;
begin
  -- FOR UPDATE bloquea la fila: dos pagos simultaneos no se pisan el saldo.
  select * into v_debt
    from public.debts
   where id = p_debt_id
     for update;

  if not found then
    raise exception 'La deuda % no existe o no tienes acceso a ella', p_debt_id
      using errcode = 'no_data_found';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'El monto del pago debe ser mayor a cero'
      using errcode = 'check_violation';
  end if;

  v_remaining := coalesce(v_debt.total_amount, 0) - coalesce(v_debt.paid_amount, 0);

  if v_remaining <= 0 then
    raise exception 'La deuda ya esta liquidada'
      using errcode = 'check_violation';
  end if;

  if p_amount > v_remaining then
    raise exception 'El pago (%) excede el saldo pendiente (%)', p_amount, v_remaining
      using errcode = 'check_violation';
  end if;

  insert into public.debt_payments (id, debt_id, amount, payment_date, note)
  values (p_payment_id, p_debt_id, p_amount, p_payment_date, p_note);

  update public.debts
     set paid_amount = coalesce(paid_amount, 0) + p_amount
   where id = p_debt_id
  returning * into v_debt;

  return v_debt;
end;
$$;

comment on function public.register_debt_payment is
  'Inserta un pago y actualiza el saldo de la deuda en una sola transaccion.';
