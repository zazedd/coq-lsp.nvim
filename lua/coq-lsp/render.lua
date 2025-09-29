local M = {}

local function pp_to_string(value)
  if type(value) == 'string' then
    return value
  elseif type(value) == 'table' then
    if value == vim.NIL then
      return ""
    end
    if value.text then
      return value.text
    end
    return vim.inspect(value)
  else
    return tostring(value)
  end
end

local function indent_continuation_lines(text, indent)
  local lines = vim.split(text, '\n')
  if #lines <= 1 then
    return text
  end
  
  for i = 2, #lines do
    if not lines[i]:match('^%s') then
      lines[i] = indent .. lines[i]
    end
  end
  
  return table.concat(lines, '\n')
end

local function break_on_arrows(text, indent)
  local lines = vim.split(text, '\n')
  if #lines <= 1 then
    return text
  end

  local result = {}
  for _, line in ipairs(lines) do
    -- split on ' -> ' and rejoin with newlines
    local parts = vim.split(line, ' %-%> ', { plain = false })
    for j, part in ipairs(parts) do
      if j == 1 then
        table.insert(result, part)
      else
        result[#result] = result[#result] .. ' ->'
        local prefix = line:match('^%s*') or ''
        if prefix == '' then
          prefix = indent
        end
        table.insert(result, prefix .. part)
      end
    end
  end
  
  return table.concat(result, '\n')
end

---@param i integer
---@param n integer
---@param goal coqlsp.Goal
---@return string[]
function M.Goal(i, n, goal)
  local lines = {}
  lines[#lines + 1] = 'Goal ' .. i .. ' / ' .. n
  for _, hyp in ipairs(goal.hyps) do
    local names_part = table.concat(hyp.names, ', ')
    local ty_str = pp_to_string(hyp.ty)
    local base_indent = '  '
    ty_str = indent_continuation_lines(ty_str, base_indent)
    ty_str = break_on_arrows(ty_str, base_indent)
    local line = names_part .. ' : ' .. ty_str

    if hyp.def and hyp.def ~= vim.NIL then
      local def_str = pp_to_string(hyp.def)
      def_str = indent_continuation_lines(def_str, base_indent)
      def_str = break_on_arrows(def_str, base_indent)
      line = line .. ' := ' .. def_str
    end

    vim.list_extend(lines, vim.split(line, '\n'))
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = '========================================'
  lines[#lines + 1] = ''
  vim.list_extend(lines, vim.split(pp_to_string(goal.ty), '\n'))
  return lines
end

---@param goals coqlsp.Goal[]
---@return string[]
function M.Goals(goals)
  local lines = {}
  for i, goal in ipairs(goals) do
    if i > 1 then
      lines[#lines + 1] = ''
      lines[#lines + 1] = ''
      lines[#lines + 1] =
        '────────────────────────────────────────────────────────────'
      lines[#lines + 1] = ''
    end
    vim.list_extend(lines, M.Goal(i, #goals, goal))
  end
  return lines
end

---@param message coqlsp.Message
---@return string[]
function M.Message(message)
  local lines = {}
  vim.list_extend(lines, vim.split(pp_to_string(message.text), '\n'))
  return lines
end

---@param messages coqlsp.Pp[] | coqlsp.Message[]
---@return string[]
function M.Messages(messages)
  local lines = {}
  for _, msg in ipairs(messages) do
    if type(msg) == 'string' then
      vim.list_extend(lines, vim.split(msg, '\n'))
    else
      vim.list_extend(lines, M.Message(msg))
    end
  end
  return lines
end

---@param answer coqlsp.GoalAnswer
---@param position MarkPosition
---@return string[]
function M.GoalAnswer(answer, position)
  local lines = {}

  local bufnr = vim.uri_to_bufnr(answer.textDocument.uri)
  lines[#lines + 1] = vim.fn.bufname(bufnr) .. ':' .. position[1] .. ':' .. (position[2] + 1)

  if answer.goals then
    if #answer.goals.goals > 0 then
      vim.list_extend(lines, M.Goals(answer.goals.goals))
    end
  end

  if #answer.messages > 0 then
    lines[#lines + 1] = ''
    lines[#lines + 1] = ''
    lines[#lines + 1] =
      'Messages ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    lines[#lines + 1] = ''
    vim.list_extend(lines, M.Messages(answer.messages))
  end

  if answer.goals then
    if #answer.goals.shelf > 0 then
      lines[#lines + 1] = ''
      lines[#lines + 1] = ''
      lines[#lines + 1] =
        'Shelved ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
      lines[#lines + 1] = ''
      vim.list_extend(lines, M.Goals(answer.goals.shelf))
    end
    if #answer.goals.given_up > 0 then
      lines[#lines + 1] = ''
      lines[#lines + 1] = ''
      lines[#lines + 1] =
        'Given Up ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
      lines[#lines + 1] = ''
      vim.list_extend(lines, M.Goals(answer.goals.given_up))
    end
  end

  if answer.error then
    lines[#lines + 1] = ''
    lines[#lines + 1] = ''
    lines[#lines + 1] =
      'Error ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    lines[#lines + 1] = ''
    vim.list_extend(lines, vim.split(pp_to_string(answer.error), '\n'))
  end

  return lines
end

return M
