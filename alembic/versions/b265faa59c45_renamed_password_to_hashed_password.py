"""Renamed password to hashed_password

Revision ID: b265faa59c45
Revises: 119f6521ac60
Create Date: 2025-02-06 05:02:44.746094

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'b265faa59c45'
down_revision: Union[str, None] = '119f6521ac60'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    # Rename the column from 'hashed_password' to 'password'
    op.alter_column('users', 'hashed_password', new_column_name='password')


def downgrade():
    # Rename it back in case we need to rollback
    op.alter_column('users', 'password', new_column_name='hashed_password')