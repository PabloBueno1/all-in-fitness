"""Merging branches

Revision ID: 62f0168e77bc
Revises: b0002bf84b0f
Create Date: 2025-02-05 04:37:24.355507

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '62f0168e77bc'
down_revision = ('b0002bf84b0f', 'ec613512c79c')
branch_labels: Union[str, Sequence[str], None] = ('merge_fix',)
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
